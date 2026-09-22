package v1

import "cue.dev/x/k8s.io/apimachinery/pkg/apis/meta/v1"

// Lease defines a lease concept.
#Lease: {
	// APIVersion defines the versioned schema of this representation of an object.
	// Servers should convert recognized schemas to the latest internal value, and
	// may reject unrecognized values. More info:
	// https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources
	"apiVersion": "coordination.k8s.io/v1"

	// Kind is a string value representing the REST resource this object represents.
	// Servers may infer this from the endpoint the client submits requests to.
	// Cannot be updated. In CamelCase. More info:
	// https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds
	"kind": "Lease"

	// More info:
	// https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata
	"metadata"?: v1.#ObjectMeta

	// spec contains the specification of the Lease. More info:
	// https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#spec-and-status
	"spec"?: #LeaseSpec
}

// LeaseList is a list of Lease objects.
#LeaseList: {
	// APIVersion defines the versioned schema of this representation of an object.
	// Servers should convert recognized schemas to the latest internal value, and
	// may reject unrecognized values. More info:
	// https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources
	"apiVersion": "coordination.k8s.io/v1"

	// items is a list of schema objects.
	"items"!: [...#Lease]

	// Kind is a string value representing the REST resource this object represents.
	// Servers may infer this from the endpoint the client submits requests to.
	// Cannot be updated. In CamelCase. More info:
	// https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds
	"kind": "LeaseList"

	// Standard list metadata. More info:
	// https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata
	"metadata"?: v1.#ListMeta
}

// LeaseSpec is a specification of a Lease.
#LeaseSpec: {
	// acquireTime is a time when the current lease was acquired.
	"acquireTime"?: v1.#MicroTime

	// holderIdentity contains the identity of the holder of a current lease. If
	// Coordinated Leader Election is used, the holder identity must be equal to
	// the elected LeaseCandidate.metadata.name field.
	"holderIdentity"?: string

	// leaseDurationSeconds is a duration that candidates for a lease need to wait
	// to force acquire it. This is measured against the time of last observed
	// renewTime.
	"leaseDurationSeconds"?: int32 & int

	// leaseTransitions is the number of transitions of a lease between holders.
	"leaseTransitions"?: int32 & int

	// PreferredHolder signals to a lease holder that the lease has a more optimal
	// holder and should be given up. This field can only be set if Strategy is
	// also set.
	"preferredHolder"?: string

	// renewTime is a time when the current holder of a lease has last updated the lease.
	"renewTime"?: v1.#MicroTime

	// Strategy indicates the strategy for picking the leader for coordinated leader
	// election. If the field is not specified, there is no active coordination for
	// this lease. (Alpha) Using this field requires the CoordinatedLeaderElection
	// feature gate to be enabled.
	"strategy"?: string
}
