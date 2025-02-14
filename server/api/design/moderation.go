package design

import (
	. "goa.design/goa/v3/dsl"
)

var ModerationRequest = Type("ModerationRequest", func() {
	Attribute("id", Int32)
	Attribute("postId", Int32)
	Attribute("postType", String)
	Attribute("reportedBy", Int32)
	Attribute("reportedAt", String)
	Attribute("acknowledgedBy", Int32)
	Attribute("acknowledgedAt", String)
	Required("id", "postId", "postType", "reportedBy", "reportedAt")
})

var ModerationAddPayload = Type("ModerationAddPayload", func() {
	Token("auth")
	Attribute("postId", Int32)
	Attribute("postType", String)
	Required("postId", "postType")
})

var _ = Service("moderation", func() {
	Method("add", func() {
		Security(JWTAuth, func() {
			Scope("api:access")
		})

		Payload(ModerationAddPayload)

		Result(ModerationRequest)

		HTTP(func() {
			POST("moderation")
			httpAuthentication()
		})
	})

	Method("acknowledge", func() {
		Security(JWTAuth, func() {
			Scope("api:access")
		})

		Payload(func() {
			Token("auth")
			Attribute("id", Int32)
			Attribute("acknowledgedBy", Int32)
			Required("id", "acknowledgedBy")
		})

		Result(ModerationRequest)

		HTTP(func() {
			POST("moderation/acknowledge")
			httpAuthentication()
		})
	})
})
