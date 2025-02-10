package main

import (
	"bytes"
	"context"
	"encoding/hex"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"io/ioutil"
	"log"
	"net/http"
	"os"

	"github.com/golang/protobuf/proto"
	stream "gitlab.com/fieldkit/cloud/server/backend"

	pbdata "gitlab.com/fieldkit/libraries/data-protocol"
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
		ms, err := ExtractMeta(ctx, options.File)
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

func ExtractMeta(ctx context.Context, path string) (*MetaScanner, error) {
	file, err := os.Open(path)
	if err != nil {
		return nil, fmt.Errorf("opening file: %w", err)
	}

	defer file.Close()

	ms := NewMetaScanner()

	if err := Decode(ctx, file, ms); err != nil {
		return nil, fmt.Errorf("decoding: %w", err)
	}

	if ms.DeviceId != nil {
		log.Printf("DeviceId: %s", hex.EncodeToString(*ms.DeviceId))
	}
	if ms.GenerationId != nil {
		log.Printf("GenerationId: %s", hex.EncodeToString(*ms.GenerationId))
	}
	if ms.DeviceName != nil {
		log.Printf("DeviceName: %s", *ms.DeviceName)
	}
	if ms.FirstRecord != nil {
		log.Printf("FirstRecord: %d", *ms.FirstRecord)
	}
	if ms.LastRecord != nil {
		log.Printf("LastRecord: %d", *ms.LastRecord)
	}

	log.Printf("Visited: %d", ms.Visited)

	return ms, nil
}

func (ms *MetaScanner) Valid() error {
	if ms.DeviceId == nil {
		return fmt.Errorf("missing: device id")
	}
	if ms.GenerationId == nil {
		return fmt.Errorf("missing: generation id")
	}
	if ms.DeviceName == nil {
		return fmt.Errorf("missing: device name")
	}
	if ms.FirstRecord == nil {
		return fmt.Errorf("missing: first record")
	}
	if ms.LastRecord == nil {
		return fmt.Errorf("missing: last record")
	}

	return nil
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
	ms, err := ExtractMeta(ctx, path)
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

type MetaScanner struct {
	DeviceId     *[]byte
	DeviceName   *string
	GenerationId *[]byte
	Visited      uint64
	FirstRecord  *uint64
	LastRecord   *uint64
}

func NewMetaScanner() *MetaScanner {
	return &MetaScanner{}
}

func (ms *MetaScanner) OnRecord(ctx context.Context, record *pbdata.DataRecord) error {
	if record.Metadata != nil {
		if record.Metadata.DeviceId != nil {
			if ms.DeviceId == nil {
				ms.DeviceId = &record.Metadata.DeviceId
			} else {
				if !bytes.Equal(*ms.DeviceId, record.Metadata.DeviceId) {
					return fmt.Errorf("multiple device ids in file")
				}
			}
		}
		if record.Metadata.Generation != nil {
			if ms.GenerationId == nil {
				ms.GenerationId = &record.Metadata.Generation
			} else {
				if !bytes.Equal(*ms.GenerationId, record.Metadata.Generation) {
					return fmt.Errorf("multiple generations in file")
				}
			}
		}
	}

	if record.Identity != nil {
		if record.Identity.Name != "" {
			if ms.DeviceName == nil {
				ms.DeviceName = &record.Identity.Name
			} else {
				if *ms.DeviceName != record.Identity.Name {
					return fmt.Errorf("multiple names in file (%s vs %s)", *ms.DeviceName, record.Identity.Name)
				}
			}
		}
	}

	number, err := getRecordNumber(record)
	if err != nil {
		return err
	}

	if number != nil {
		if ms.FirstRecord == nil {
			ms.FirstRecord = number
		}
		if ms.LastRecord == nil || *ms.LastRecord < *number {
			ms.LastRecord = number
		} else {
			return fmt.Errorf("non-monotonic record")
		}
	}

	ms.Visited += 1

	return nil
}

func getRecordNumber(record *pbdata.DataRecord) (*uint64, error) {
	if record.Readings != nil {
		if record.Readings.Reading == 0 {
			// Sanity check. This should never happen, as we'll need a meta
			// record first, so we can't have a zero reading record.
			return nil, fmt.Errorf("zero readings record")
		}
		return &record.Readings.Reading, nil
	}
	if record.Metadata != nil {
		return &record.Metadata.Record, nil
	}
	// All records from modern firmware should have a number. There are hacks we
	// can fallback in if we ever see an old file in here.
	return nil, fmt.Errorf("no record number")
}

type RecordVisitor interface {
	OnRecord(ctx context.Context, record *pbdata.DataRecord) error
}

func Decode(ctx context.Context, reader io.Reader, visitor RecordVisitor) error {
	unmarshalFunc := stream.UnmarshalFunc(func(b []byte) (proto.Message, error) {
		var record pbdata.DataRecord
		err := proto.Unmarshal(b, &record)
		if err != nil {
			return nil, err
		}

		if err := visitor.OnRecord(ctx, &record); err != nil {
			log.Printf("error: %s", err)

			replyJson, err := json.MarshalIndent(&record, "", "  ")
			if err != nil {
				return nil, err
			}

			fmt.Println(string(replyJson))

			return nil, err
		}

		return nil, nil
	})

	_, _, err := stream.ReadLengthPrefixedCollection(ctx, stream.MaximumDataRecordLength, reader, unmarshalFunc)
	if err != nil {
		return err
	}

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
