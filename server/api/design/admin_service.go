package design

import (
	. "goa.design/goa/v3/dsl"
)

var _ = Service("admin", func() {
	Method("health", func() {
		Security(JWTAuth, func() {
			Scope("api:admin")
		})

		Payload(func() {
			Token("auth")
			Required("auth")
		})

		Result(Health)

		HTTP(func() {
			GET("admin/health")

			httpAuthentication()
		})
	})

	commonOptions()
})

var Health = ResultType("application/vnd.app.health+json", func() {
	TypeName("Health")
	Attributes(func() {
		Attribute("queue", QueueHealth)
		Required("queue")
	})
	View("default", func() {
		Attribute("queue")
	})
})

var QueueHealth = Type("QueueHealth", func() {
	Attribute("pending", Int64)
	Attribute("errors", Int64)
	Required("pending", "errors")
})
