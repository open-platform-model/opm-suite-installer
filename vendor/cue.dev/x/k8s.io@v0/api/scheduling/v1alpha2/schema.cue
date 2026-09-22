package v1alpha2

import "cue.dev/x/k8s.io/apimachinery/pkg/apis/meta/v1"

// BasicSchedulingPolicy indicates that standard Kubernetes scheduling behavior should be used.
#BasicSchedulingPolicy: {}

// GangSchedulingPolicy defines the parameters for gang scheduling.
#GangSchedulingPolicy: {
	// MinCount is the minimum number of pods that must be schedulable or scheduled
	// at the same time for the scheduler to admit the entire group. It must be a
	// positive integer.
	"minCount"!: int32 & int
}

// PodGroup represents a runtime instance of pods grouped together. PodGroups
// are created by workload controllers (Job, LWS, JobSet, etc...) from
// Workload.podGroupTemplates. PodGroup API enablement is toggled by the
// GenericWorkload feature gate.
#PodGroup: {
	// APIVersion defines the versioned schema of this representation of an object.
	// Servers should convert recognized schemas to the latest internal value, and
	// may reject unrecognized values. More info:
	// https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources
	"apiVersion": "scheduling.k8s.io/v1alpha2"

	// Kind is a string value representing the REST resource this object represents.
	// Servers may infer this from the endpoint the client submits requests to.
	// Cannot be updated. In CamelCase. More info:
	// https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds
	"kind": "PodGroup"

	// Standard object's metadata. More info:
	// https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata
	"metadata"?: v1.#ObjectMeta

	// Spec defines the desired state of the PodGroup.
	"spec"!: #PodGroupSpec

	// Status represents the current observed state of the PodGroup.
	"status"?: #PodGroupStatus
}

// PodGroupList contains a list of PodGroup resources.
#PodGroupList: {
	// APIVersion defines the versioned schema of this representation of an object.
	// Servers should convert recognized schemas to the latest internal value, and
	// may reject unrecognized values. More info:
	// https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources
	"apiVersion": "scheduling.k8s.io/v1alpha2"

	// Items is the list of PodGroups.
	"items"!: [...#PodGroup]

	// Kind is a string value representing the REST resource this object represents.
	// Servers may infer this from the endpoint the client submits requests to.
	// Cannot be updated. In CamelCase. More info:
	// https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds
	"kind": "PodGroupList"

	// Standard list metadata.
	"metadata"?: v1.#ListMeta
}

// PodGroupResourceClaim references exactly one ResourceClaim, either directly
// or by naming a ResourceClaimTemplate which is then turned into a
// ResourceClaim for the PodGroup.
//
// It adds a name to it that uniquely identifies the ResourceClaim inside the
// PodGroup. Pods that need access to the ResourceClaim define a matching
// reference in its own Spec.ResourceClaims. The Pod's claim must match all
// fields of the PodGroup's claim exactly.
#PodGroupResourceClaim: {
	// Name uniquely identifies this resource claim inside the PodGroup. This must be a DNS_LABEL.
	"name"!: string

	// ResourceClaimName is the name of a ResourceClaim object in the same namespace
	// as this PodGroup. The ResourceClaim will be reserved for the PodGroup
	// instead of its individual pods.
	//
	// Exactly one of ResourceClaimName and ResourceClaimTemplateName must be set.
	"resourceClaimName"?: string

	// ResourceClaimTemplateName is the name of a ResourceClaimTemplate object in
	// the same namespace as this PodGroup.
	//
	// The template will be used to create a new ResourceClaim, which will be bound
	// to this PodGroup. When this PodGroup is deleted, the ResourceClaim will also
	// be deleted. The PodGroup name and resource name, along with a generated
	// component, will be used to form a unique name for the ResourceClaim, which
	// will be recorded in podgroup.status.resourceClaimStatuses.
	//
	// This field is immutable and no changes will be made to the corresponding
	// ResourceClaim by the control plane after creating the ResourceClaim.
	//
	// Exactly one of ResourceClaimName and ResourceClaimTemplateName must be set.
	"resourceClaimTemplateName"?: string
}

// PodGroupResourceClaimStatus is stored in the PodGroupStatus for each
// PodGroupResourceClaim which references a ResourceClaimTemplate. It stores
// the generated name for the corresponding ResourceClaim.
#PodGroupResourceClaimStatus: {
	// Name uniquely identifies this resource claim inside the PodGroup. This must
	// match the name of an entry in podgroup.spec.resourceClaims, which implies
	// that the string must be a DNS_LABEL.
	"name"!: string

	// ResourceClaimName is the name of the ResourceClaim that was generated for the
	// PodGroup in the namespace of the PodGroup. If this is unset, then generating
	// a ResourceClaim was not necessary. The podgroup.spec.resourceClaims entry
	// can be ignored in this case.
	"resourceClaimName"?: string
}

// PodGroupSchedulingConstraints defines scheduling constraints (e.g. topology) for a PodGroup.
#PodGroupSchedulingConstraints: {
	// Topology defines the topology constraints for the pod group. Currently only a
	// single topology constraint can be specified. This may change in the future.
	"topology"?: [...#TopologyConstraint]
}

// PodGroupSchedulingPolicy defines the scheduling configuration for a PodGroup.
// Exactly one policy must be set.
#PodGroupSchedulingPolicy: {
	// Basic specifies that the pods in this group should be scheduled using
	// standard Kubernetes scheduling behavior.
	"basic"?: #BasicSchedulingPolicy

	// Gang specifies that the pods in this group should be scheduled using all-or-nothing semantics.
	"gang"?: #GangSchedulingPolicy
}

// PodGroupSpec defines the desired state of a PodGroup.
#PodGroupSpec: {
	// DisruptionMode defines the mode in which a given PodGroup can be disrupted.
	// Controllers are expected to fill this field by copying it from a
	// PodGroupTemplate. One of Pod, PodGroup. Defaults to Pod if unset. This field
	// is immutable. This field is available only when the WorkloadAwarePreemption
	// feature gate is enabled.
	"disruptionMode"?: string

	// PodGroupTemplateRef references an optional PodGroup template within other
	// object (e.g. Workload) that was used to create the PodGroup. This field is
	// immutable.
	"podGroupTemplateRef"?: #PodGroupTemplateReference

	// Priority is the value of priority of this pod group. Various system
	// components use this field to find the priority of the pod group. When
	// Priority Admission Controller is enabled, it prevents users from setting
	// this field. The admission controller populates this field from
	// PriorityClassName. The higher the value, the higher the priority. This field
	// is immutable. This field is available only when the WorkloadAwarePreemption
	// feature gate is enabled.
	"priority"?: int32 & int

	// PriorityClassName defines the priority that should be considered when
	// scheduling this pod group. Controllers are expected to fill this field by
	// copying it from a PodGroupTemplate. Otherwise, it is validated and resolved
	// similarly to the PriorityClassName on PodGroupTemplate (i.e. if no priority
	// class is specified, admission control can set this to the global default
	// priority class if it exists. Otherwise, the pod group's priority will be
	// zero). This field is immutable. This field is available only when the
	// WorkloadAwarePreemption feature gate is enabled.
	"priorityClassName"?: string

	// ResourceClaims defines which ResourceClaims may be shared among Pods in the
	// group. Pods consume the devices allocated to a PodGroup's claim by defining
	// a claim in its own Spec.ResourceClaims that matches the PodGroup's claim
	// exactly. The claim must have the same name and refer to the same
	// ResourceClaim or ResourceClaimTemplate.
	//
	// This is an alpha-level field and requires that the DRAWorkloadResourceClaims
	// feature gate is enabled.
	//
	// This field is immutable.
	"resourceClaims"?: [...#PodGroupResourceClaim]

	// SchedulingConstraints defines optional scheduling constraints (e.g. topology)
	// for this PodGroup. Controllers are expected to fill this field by copying it
	// from a PodGroupTemplate. This field is immutable. This field is only
	// available when the TopologyAwareWorkloadScheduling feature gate is enabled.
	"schedulingConstraints"?: #PodGroupSchedulingConstraints

	// SchedulingPolicy defines the scheduling policy for this instance of the
	// PodGroup. Controllers are expected to fill this field by copying it from a
	// PodGroupTemplate. This field is immutable.
	"schedulingPolicy"!: #PodGroupSchedulingPolicy
}

// PodGroupStatus represents information about the status of a pod group.
#PodGroupStatus: {
	// Conditions represent the latest observations of the PodGroup's state.
	//
	// Known condition types: - "PodGroupScheduled": Indicates whether the
	// scheduling requirement has been satisfied. - "DisruptionTarget": Indicates
	// whether the PodGroup is about to be terminated
	// due to disruption such as preemption.
	//
	// Known reasons for the PodGroupScheduled condition: - "Unschedulable": The
	// PodGroup cannot be scheduled due to resource constraints,
	// affinity/anti-affinity rules, or insufficient capacity for the gang.
	// - "SchedulerError": The PodGroup cannot be scheduled due to some internal error
	// that happened during scheduling, for example due to nodeAffinity parsing errors.
	//
	// Known reasons for the DisruptionTarget condition: - "PreemptionByScheduler":
	// The PodGroup was preempted by the scheduler to make room for
	// higher-priority PodGroups or Pods.
	"conditions"?: [...v1.#Condition]

	// Status of resource claims.
	"resourceClaimStatuses"?: [...#PodGroupResourceClaimStatus]
}

// PodGroupTemplate represents a template for a set of pods with a scheduling policy.
#PodGroupTemplate: {
	// DisruptionMode defines the mode in which a given PodGroup can be disrupted.
	// One of Pod, PodGroup. This field is available only when the
	// WorkloadAwarePreemption feature gate is enabled.
	"disruptionMode"?: string

	// Name is a unique identifier for the PodGroupTemplate within the Workload. It
	// must be a DNS label. This field is immutable.
	"name"!: string

	// Priority is the value of priority of pod groups created from this template.
	// Various system components use this field to find the priority of the pod
	// group. When Priority Admission Controller is enabled, it prevents users from
	// setting this field. The admission controller populates this field from
	// PriorityClassName. The higher the value, the higher the priority. This field
	// is available only when the WorkloadAwarePreemption feature gate is enabled.
	"priority"?: int32 & int

	// PriorityClassName indicates the priority that should be considered when
	// scheduling a pod group created from this template. If no priority class is
	// specified, admission control can set this to the global default priority
	// class if it exists. Otherwise, pod groups created from this template will
	// have the priority set to zero. This field is available only when the
	// WorkloadAwarePreemption feature gate is enabled.
	"priorityClassName"?: string

	// ResourceClaims defines which ResourceClaims may be shared among Pods in the
	// group. Pods consume the devices allocated to a PodGroup's claim by defining
	// a claim in its own Spec.ResourceClaims that matches the PodGroup's claim
	// exactly. The claim must have the same name and refer to the same
	// ResourceClaim or ResourceClaimTemplate.
	//
	// This is an alpha-level field and requires that the DRAWorkloadResourceClaims
	// feature gate is enabled.
	//
	// This field is immutable.
	"resourceClaims"?: [...#PodGroupResourceClaim]

	// SchedulingConstraints defines optional scheduling constraints (e.g. topology)
	// for this PodGroupTemplate. This field is only available when the
	// TopologyAwareWorkloadScheduling feature gate is enabled.
	"schedulingConstraints"?: #PodGroupSchedulingConstraints

	// SchedulingPolicy defines the scheduling policy for this PodGroupTemplate.
	"schedulingPolicy"!: #PodGroupSchedulingPolicy
}

// PodGroupTemplateReference references a PodGroup template defined in some
// object (e.g. Workload). Exactly one reference must be set.
#PodGroupTemplateReference: {
	// Workload references the PodGroupTemplate within the Workload object that was
	// used to create the PodGroup.
	"workload"?: #WorkloadPodGroupTemplateReference
}

// TopologyConstraint defines a topology constraint for a PodGroup.
#TopologyConstraint: {
	// Key specifies the key of the node label representing the topology domain. All
	// pods within the PodGroup must be colocated within the same domain instance.
	// Different PodGroups can land on different domain instances even if they
	// derive from the same PodGroupTemplate. Examples:
	// "topology.kubernetes.io/rack"
	"key"!: string
}

// TypedLocalObjectReference allows to reference typed object inside the same namespace.
#TypedLocalObjectReference: {
	// APIGroup is the group for the resource being referenced. If APIGroup is
	// empty, the specified Kind must be in the core API group. For any other
	// third-party types, setting APIGroup is required. It must be a DNS subdomain.
	"apiGroup"?: string

	// Kind is the type of resource being referenced. It must be a path segment name.
	"kind"!: string

	// Name is the name of resource being referenced. It must be a path segment name.
	"name"!: string
}

// Workload allows for expressing scheduling constraints that should be used
// when managing the lifecycle of workloads from the scheduling perspective,
// including scheduling, preemption, eviction and other phases. Workload API
// enablement is toggled by the GenericWorkload feature gate.
#Workload: {
	// APIVersion defines the versioned schema of this representation of an object.
	// Servers should convert recognized schemas to the latest internal value, and
	// may reject unrecognized values. More info:
	// https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources
	"apiVersion": "scheduling.k8s.io/v1alpha2"

	// Kind is a string value representing the REST resource this object represents.
	// Servers may infer this from the endpoint the client submits requests to.
	// Cannot be updated. In CamelCase. More info:
	// https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds
	"kind": "Workload"

	// Standard object's metadata. More info:
	// https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata
	"metadata"?: v1.#ObjectMeta

	// Spec defines the desired behavior of a Workload.
	"spec"!: #WorkloadSpec
}

// WorkloadList contains a list of Workload resources.
#WorkloadList: {
	// APIVersion defines the versioned schema of this representation of an object.
	// Servers should convert recognized schemas to the latest internal value, and
	// may reject unrecognized values. More info:
	// https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources
	"apiVersion": "scheduling.k8s.io/v1alpha2"

	// Items is the list of Workloads.
	"items"!: [...#Workload]

	// Kind is a string value representing the REST resource this object represents.
	// Servers may infer this from the endpoint the client submits requests to.
	// Cannot be updated. In CamelCase. More info:
	// https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds
	"kind": "WorkloadList"

	// Standard list metadata.
	"metadata"?: v1.#ListMeta
}

// WorkloadPodGroupTemplateReference references the PodGroupTemplate within the Workload object.
#WorkloadPodGroupTemplateReference: {
	// PodGroupTemplateName defines the PodGroupTemplate name within the Workload object.
	"podGroupTemplateName"!: string

	// WorkloadName defines the name of the Workload object.
	"workloadName"!: string
}

// WorkloadSpec defines the desired state of a Workload.
#WorkloadSpec: {
	// ControllerRef is an optional reference to the controlling object, such as a
	// Deployment or Job. This field is intended for use by tools like CLIs to
	// provide a link back to the original workload definition. This field is
	// immutable.
	"controllerRef"?: #TypedLocalObjectReference

	// PodGroupTemplates is the list of templates that make up the Workload. The
	// maximum number of templates is 8. This field is immutable.
	"podGroupTemplates"!: [...#PodGroupTemplate]
}
