package v1alpha1

import "cue.dev/x/k8s.io/apimachinery/pkg/apis/meta/v1"

// An API server instance reports the version it can decode and the version it
// encodes objects to when persisting objects in the backend.
#ServerStorageVersion: {
	// apiServerID is the ID of the reporting API server.
	"apiServerID"!: string

	// decodableVersions are the encoding versions the API server can handle to
	// decode. The API server can decode objects encoded in these versions. The
	// encodingVersion must be included in the decodableVersions.
	"decodableVersions"!: [...string]

	// encodingVersion the API server encodes the object to when persisting it in
	// the backend (e.g., etcd).
	"encodingVersion"!: string

	// servedVersions lists all versions the API server can serve. DecodableVersions
	// must include all ServedVersions.
	"servedVersions"?: [...string]
}

// Storage version of a specific resource.
#StorageVersion: {
	// APIVersion defines the versioned schema of this representation of an object.
	// Servers should convert recognized schemas to the latest internal value, and
	// may reject unrecognized values. More info:
	// https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources
	"apiVersion": "internal.apiserver.k8s.io/v1alpha1"

	// Kind is a string value representing the REST resource this object represents.
	// Servers may infer this from the endpoint the client submits requests to.
	// Cannot be updated. In CamelCase. More info:
	// https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds
	"kind": "StorageVersion"

	// metadata is the standard object metadata. The name is <group>.<resource>.
	"metadata"!: v1.#ObjectMeta

	// spec is an empty spec. It is here to comply with Kubernetes API style.
	"spec"?: #StorageVersionSpec

	// status on the version the API server instance can decode from and encode
	// objects to when persisting objects in the backend.
	"status"?: #StorageVersionStatus
}

// Describes the state of the storageVersion at a certain point.
#StorageVersionCondition: {
	// lastTransitionTime is the last time the condition transitioned from one status to another.
	"lastTransitionTime"?: v1.#Time

	// message is a human readable string indicating details about the transition.
	"message"!: string

	// observedGeneration represents the .metadata.generation that the condition was
	// set based upon, if field is set.
	"observedGeneration"?: int64 & int

	// reason for the condition's last transition.
	"reason"!: string

	// status of the condition, one of True, False, Unknown.
	"status"!: string

	// type of the condition.
	"type"!: string
}

// A list of StorageVersions.
#StorageVersionList: {
	// APIVersion defines the versioned schema of this representation of an object.
	// Servers should convert recognized schemas to the latest internal value, and
	// may reject unrecognized values. More info:
	// https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources
	"apiVersion": "internal.apiserver.k8s.io/v1alpha1"

	// Items holds a list of StorageVersion
	"items"!: [...#StorageVersion]

	// Kind is a string value representing the REST resource this object represents.
	// Servers may infer this from the endpoint the client submits requests to.
	// Cannot be updated. In CamelCase. More info:
	// https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds
	"kind": "StorageVersionList"

	// Standard list metadata. More info:
	// https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata
	"metadata"?: v1.#ListMeta
}

// StorageVersionSpec is an empty spec.
#StorageVersionSpec: {}

// API server instances report the versions they can decode and the version they
// encode objects to when persisting objects in the backend.
#StorageVersionStatus: {
	// commonEncodingVersion is set to an encoding storage version if all API server
	// instances share that same version. If they don't share one storage version,
	// this field is left empty. API servers should finish updating its
	// storageVersionStatus entry before serving write operations, so that this
	// field will be in sync with the reality.
	"commonEncodingVersion"?: string

	// conditions lists the latest available observations of the storageVersion's state.
	"conditions"?: [...#StorageVersionCondition]

	// storageVersions lists the reported versions per API server instance.
	"storageVersions"?: [...#ServerStorageVersion]
}
