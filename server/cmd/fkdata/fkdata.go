package main

import (
	"bytes"
	"context"
	"encoding/hex"
	"encoding/json"
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"os"

	backend "gitlab.com/fieldkit/cloud/server/backend"
)

type Options struct {
	File   string
	Portal string
}

func main() {
	ctx := context.Background()

	options := Options{}
	flag.StringVar(&options.File, "file", "", "fkpb file")
	flag.StringVar(&options.Portal, "portal", "", "portal url")
	flag.Parse()

	if options.File == "" {
		flag.Usage()
		return
	}

	if options.Portal == "" {
		ms, err := backend.ExtractMeta(ctx, options.File)
		if err != nil {
			log.Fatalf("Error: %v", err)
		}

		if err := ms.Valid(); err != nil {
			log.Fatalf("Error: %v", err)
		}
	} else {
		credentials, err := CredentialsFromEnv()
		if err != nil {
			log.Fatalf("Error: %v", err)
		}

		if err := Upload(ctx, credentials, options.File, options.Portal); err != nil {
			log.Fatalf("Error: %v", err)
		}
	}
}

type Credentials struct {
	Email    string
	Password string
}

func CredentialsFromEnv() (*Credentials, error) {
	email := os.Getenv("FIELDKIT_EMAIL")
	if email == "" {
		return nil, fmt.Errorf("FIELDKIT_EMAIL missing")
	}

	password := os.Getenv("FIELDKIT_PASSWORD")
	if password == "" {
		return nil, fmt.Errorf("FIELDKIT_PASSWORD missing")
	}

	return &Credentials{
		Email:    email,
		Password: password,
	}, nil
}

func Upload(ctx context.Context, credentials *Credentials, path string, url string) error {
	ms, err := backend.ExtractMeta(ctx, path)
	if err != nil {
		return err
	}

	if err := ms.Valid(); err != nil {
		log.Fatalf("Error: %v", err)
	}

	fkc := NewFkClient(url)

	token, err := fkc.Login(ctx, credentials.Email, credentials.Password)
	if err != nil {
		return err
	}

	file, err := os.Open(path)
	if err != nil {
		return err
	}

	stat, err := file.Stat()
	if err != nil {
		return err
	}

	defer file.Close()

	req, err := http.NewRequest("POST", fmt.Sprintf("%s/ingestion", url), file)
	if err != nil {
		return err
	}

	req.ContentLength = stat.Size()

	req.Header.Set("Content-Type", "application/octet-stream")
	req.Header.Set("Authorization", token)
	req.Header.Set("Fk-Blocks", fmt.Sprintf("%d,%d", *ms.FirstRecord, *ms.LastRecord))
	req.Header.Set("Fk-DeviceId", hex.EncodeToString(*ms.DeviceId))
	req.Header.Set("Fk-DeviceName", *ms.DeviceName)
	req.Header.Set("Fk-Generation", hex.EncodeToString(*ms.GenerationId))
	req.Header.Set("Fk-Type", "data")

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		return err
	}

	log.Printf("response: %v", resp.StatusCode)

	defer resp.Body.Close()

	return nil
}

type FkClient struct {
	base string
	http *http.Client
	auth string
}

func NewFkClient(base string) (fkc *FkClient) {
	return &FkClient{
		base: base,
		http: http.DefaultClient,
	}
}

func (fkc *FkClient) Login(ctx context.Context, email, password string) (string, error) {
	type LoginPayload struct {
		Email    string `json:"email"`
		Password string `json:"password"`
	}

	payload := &LoginPayload{
		Email:    email,
		Password: password,
	}

	requestBody, err := json.Marshal(payload)
	if err != nil {
		return "", err
	}

	url := fmt.Sprintf("%s/login", fkc.base)
	req, err := http.NewRequest("POST", url, bytes.NewBuffer(requestBody))
	if err != nil {
		return "", err
	}

	response, err := fkc.http.Do(req)
	if err != nil {
		return "", err
	}

	defer response.Body.Close()

	if response.StatusCode != http.StatusNoContent {
		return "", fmt.Errorf("invalid username or password")
	}

	body, err := ioutil.ReadAll(response.Body)
	if err != nil {
		return "", err
	}

	fkc.auth = response.Header.Get("Authorization")

	_ = body

	return fkc.auth, nil
}
