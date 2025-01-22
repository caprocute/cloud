package design

import (
	. "goa.design/goa/v3/dsl"
)

var ModeratedPost = ResultType("application/vnd.app.moderation.media", func() {
	TypeName("ModeratedPost")
	Attributes(func() {
		Attribute("id", Int64)
		Attribute("post_id", Int64)
		Attribute("post_type", String)
		Attribute("reported_by", Int64)
		Attribute("reported_at", String, func() {
			Format(FormatDateTime)
		})
		Attribute("acknowledged_by", Int64)
		Attribute("acknowledged_at", String, func() {
			Format(FormatDateTime)
		})
		Required("id", "post_id", "post_type", "reported_by", "reported_at")
	})
	View("default", func() {
		Attribute("id")
		Attribute("post_id")
		Attribute("post_type")
		Attribute("reported_by")
		Attribute("reported_at")
		Attribute("acknowledged_by")
		Attribute("acknowledged_at")
	})
})

var _ = Service("moderation", func() {
	Method("add", func() {

		Security(JWTAuth, func() {
			Scope("api:access")
		})

		Payload(func() {
			Token("auth")
			Required("auth")
			Attribute("post_id", Int64)
			Attribute("post_type", String)
			Required("post_id", "post_type")
		})

		Result(ModeratedPost)

		HTTP(func() {
			POST("/moderation")

			Response(StatusCreated)
		})
	})
})
