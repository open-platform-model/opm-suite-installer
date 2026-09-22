package v1

import "cue.dev/x/k8s.io/apimachinery/pkg/apis/meta/v1"

// BoundObjectReference is a reference to an object that a token is bound to.
#BoundObjectReference: {
	// apiVersion is API version of the referent.
	"apiVersion"?: string

	// kind of the referent. Valid kinds are 'Pod' and 'Secret'.
	"kind"?: string

	// name of the referent.
	"name"?: string

	// uid of the referent.
	"uid"?: string
}

// SelfSubjectReview contains the user information that the kube-apiserver has
// about the user making this request. When using impersonation, users will
// receive the user info of the user being impersonated. If impersonation or
// request header authentication is used, any extra keys will have their case
// ignored and returned as lowercase.
#SelfSubjectReview: {
	// APIVersion defines the versioned schema of this representation of an object.
	// Servers should convert recognized schemas to the latest internal value, and
	// may reject unrecognized values. More info:
	// https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources
	"apiVersion": "authentication.k8s.io/v1"

	// Kind is a string value representing the REST resource this object represents.
	// Servers may infer this from the endpoint the client submits requests to.
	// Cannot be updated. In CamelCase. More info:
	// https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds
	"kind": "SelfSubjectReview"

	// metadata is standard object's metadata. More info:
	// https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata
	"metadata"?: v1.#ObjectMeta

	// status is filled in by the server with the user attributes.
	"status"?: #SelfSubjectReviewStatus
}

// SelfSubjectReviewStatus is filled by the kube-apiserver and sent back to a user.
#SelfSubjectReviewStatus: {
	// userInfo is a set of attributes belonging to the user making this request.
	"userInfo"?: #UserInfo
}

// TokenRequest requests a token for a given service account.
#TokenRequest: {
	// APIVersion defines the versioned schema of this representation of an object.
	// Servers should convert recognized schemas to the latest internal value, and
	// may reject unrecognized values. More info:
	// https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources
	"apiVersion": "authentication.k8s.io/v1"

	// Kind is a string value representing the REST resource this object represents.
	// Servers may infer this from the endpoint the client submits requests to.
	// Cannot be updated. In CamelCase. More info:
	// https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds
	"kind": "TokenRequest"

	// metadata is the standard object's metadata. More info:
	// https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata
	"metadata"?: v1.#ObjectMeta

	// spec holds information about the request being evaluated
	"spec"?: #TokenRequestSpec

	// status is filled in by the server and indicates whether the token can be authenticated.
	"status"?: #TokenRequestStatus
}

// TokenRequestSpec contains client provided parameters of a token request.
#TokenRequestSpec: {
	// audiences are the intendend audiences of the token. A recipient of a token
	// must identify themself with an identifier in the list of audiences of the
	// token, and otherwise should reject the token. A token issued for multiple
	// audiences may be used to authenticate against any of the audiences listed
	// but implies a high degree of trust between the target audiences.
	"audiences"?: [...string]

	// boundObjectRef is a reference to an object that the token will be bound to.
	// The token will only be valid for as long as the bound object exists. NOTE:
	// The API server's TokenReview endpoint will validate the BoundObjectRef, but
	// other audiences may not. Keep ExpirationSeconds small if you want prompt
	// revocation.
	"boundObjectRef"?: #BoundObjectReference

	// expirationSeconds is the requested duration of validity of the request. The
	// token issuer may return a token with a different validity duration so a
	// client needs to check the 'expiration' field in a response.
	"expirationSeconds"?: int64 & int
}

// TokenRequestStatus is the result of a token request.
#TokenRequestStatus: {
	// expirationTimestamp is the time of expiration of the returned token.
	"expirationTimestamp"?: v1.#Time

	// token is the opaque bearer token.
	"token"?: string
}

// TokenReview attempts to authenticate a token to a known user. Note:
// TokenReview requests may be cached by the webhook token authenticator plugin
// in the kube-apiserver.
#TokenReview: {
	// APIVersion defines the versioned schema of this representation of an object.
	// Servers should convert recognized schemas to the latest internal value, and
	// may reject unrecognized values. More info:
	// https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources
	"apiVersion": "authentication.k8s.io/v1"

	// Kind is a string value representing the REST resource this object represents.
	// Servers may infer this from the endpoint the client submits requests to.
	// Cannot be updated. In CamelCase. More info:
	// https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds
	"kind": "TokenReview"

	// metadata is the standard object's metadata. More info:
	// https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata
	"metadata"?: v1.#ObjectMeta

	// spec holds information about the request being evaluated
	"spec"!: #TokenReviewSpec

	// status is filled in by the server and indicates whether the request can be authenticated.
	"status"?: #TokenReviewStatus
}

// TokenReviewSpec is a description of the token authentication request.
#TokenReviewSpec: {
	// audiences is a list of the identifiers that the resource server presented
	// with the token identifies as. Audience-aware token authenticators will
	// verify that the token was intended for at least one of the audiences in this
	// list. If no audiences are provided, the audience will default to the
	// audience of the Kubernetes apiserver.
	"audiences"?: [...string]

	// token is the opaque bearer token.
	"token"!: string
}

// TokenReviewStatus is the result of the token authentication request.
#TokenReviewStatus: {
	// audiences are audience identifiers chosen by the authenticator that are
	// compatible with both the TokenReview and token. An identifier is any
	// identifier in the intersection of the TokenReviewSpec audiences and the
	// token's audiences. A client of the TokenReview API that sets the
	// spec.audiences field should validate that a compatible audience identifier
	// is returned in the status.audiences field to ensure that the TokenReview
	// server is audience aware. If a TokenReview returns an empty status.audience
	// field where status.authenticated is "true", the token is valid against the
	// audience of the Kubernetes API server.
	"audiences"?: [...string]

	// authenticated indicates that the token was associated with a known user.
	"authenticated"?: bool

	// error indicates that the token couldn't be checked
	"error"?: string

	// user is the UserInfo associated with the provided token.
	"user"?: #UserInfo
}

// UserInfo holds the information about the user needed to implement the user.Info interface.
#UserInfo: {
	// extra is any additional information provided by the authenticator.
	"extra"?: [string]: [...string]

	// groups is the names of groups this user is a part of.
	"groups"?: [...string]

	// uid is a unique value that identifies this user across time. If this user is
	// deleted and another user by the same name is added, they will have different
	// UIDs.
	"uid"?: string

	// username is the name that uniquely identifies this user among all active users.
	"username"?: string
}
