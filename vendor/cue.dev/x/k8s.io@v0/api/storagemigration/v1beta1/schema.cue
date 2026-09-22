package v1beta1

import "cue.dev/x/k8s.io/apimachinery/pkg/apis/meta/v1"

// StorageVersionMigration represents a migration of stored data to the latest storage version.
#StorageVersionMigration: {
	// APIVersion defines the versioned schema of this representation of an object.
	// Servers should convert recognized schemas to the latest internal value, and
	// may reject unrecognized values. More info:
	// https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources
	"apiVersion": "storagemigration.k8s.io/v1beta1"

	// Kind is a string value representing the REST resource this object represents.
	// Servers may infer this from the endpoint the client submits requests to.
	// Cannot be updated. In CamelCase. More info:
	// https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds
	"kind": "StorageVersionMigration"

	// Standard object metadata. More info:
	// https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata
	"metadata"?: v1.#ObjectMeta

	// Specification of the migration.
	"spec"?: #StorageVersionMigrationSpec

	// Status of the migration.
	"status"?: #StorageVersionMigrationStatus
}

// StorageVersionMigrationList is a collection of storage version migrations.
#StorageVersionMigrationList: {
	// APIVersion defines the versioned schema of this representation of an object.
	// Servers should convert recognized schemas to the latest internal value, and
	// may reject unrecognized values. More info:
	// https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources
	"apiVersion": "storagemigration.k8s.io/v1beta1"

	// Items is the list of StorageVersionMigration
	"items"!: [...#StorageVersionMigration]

	// Kind is a string value representing the REST resource this object represents.
	// Servers may infer this from the endpoint the client submits requests to.
	// Cannot be updated. In CamelCase. More info:
	// https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds
	"kind": "StorageVersionMigrationList"

	// Standard list metadata More info:
	// https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata
	"metadata"?: v1.#ListMeta
}

// Spec of the storage version migration.
#StorageVersionMigrationSpec: {
	// The resource that is being migrated. The migrator sends requests to the
	// endpoint serving the resource. Immutable.
	"resource"!: v1.#GroupResource
}

// Status of the storage version migration.
#StorageVersionMigrationStatus: {
	// The latest available observations of the migration's current state.
	"conditions"?: [...v1.#Condition]

	// ResourceVersion to compare with the GC cache for performing the migration.
	// This is the current resource version of given group, version and resource
	// when kube-controller-manager first observes this StorageVersionMigration
	// resource.
	"resourceVersion"?: string
}
