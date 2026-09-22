package v1

import "cue.dev/x/k8s.io/apimachinery/pkg/apis/meta/v1"

// CrossVersionObjectReference contains enough information to let you identify
// the referred resource.
#CrossVersionObjectReference: {
	// apiVersion is the API version of the referent
	"apiVersion"?: string

	// kind is the kind of the referent; More info:
	// https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds
	"kind"!: string

	// name is the name of the referent; More info:
	// https://kubernetes.io/docs/concepts/overview/working-with-objects/names/#names
	"name"!: string
}

// configuration of a horizontal pod autoscaler.
#HorizontalPodAutoscaler: {
	// APIVersion defines the versioned schema of this representation of an object.
	// Servers should convert recognized schemas to the latest internal value, and
	// may reject unrecognized values. More info:
	// https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources
	"apiVersion": "autoscaling/v1"

	// Kind is a string value representing the REST resource this object represents.
	// Servers may infer this from the endpoint the client submits requests to.
	// Cannot be updated. In CamelCase. More info:
	// https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds
	"kind": "HorizontalPodAutoscaler"

	// Standard object metadata. More info:
	// https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata
	"metadata"?: v1.#ObjectMeta

	// spec defines the behaviour of autoscaler. More info:
	// https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#spec-and-status.
	"spec"!: #HorizontalPodAutoscalerSpec

	// status is the current information about the autoscaler.
	"status"?: #HorizontalPodAutoscalerStatus
}

// list of horizontal pod autoscaler objects.
#HorizontalPodAutoscalerList: {
	// APIVersion defines the versioned schema of this representation of an object.
	// Servers should convert recognized schemas to the latest internal value, and
	// may reject unrecognized values. More info:
	// https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources
	"apiVersion": "autoscaling/v1"

	// items is the list of horizontal pod autoscaler objects.
	"items"!: [...#HorizontalPodAutoscaler]

	// Kind is a string value representing the REST resource this object represents.
	// Servers may infer this from the endpoint the client submits requests to.
	// Cannot be updated. In CamelCase. More info:
	// https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds
	"kind": "HorizontalPodAutoscalerList"

	// Standard list metadata.
	"metadata"?: v1.#ListMeta
}

// specification of a horizontal pod autoscaler.
#HorizontalPodAutoscalerSpec: {
	// maxReplicas is the upper limit for the number of pods that can be set by the
	// autoscaler; cannot be smaller than MinReplicas.
	"maxReplicas"!: int32 & int

	// minReplicas is the lower limit for the number of replicas to which the
	// autoscaler can scale down. It defaults to 1 pod. minReplicas is allowed to
	// be 0 if the alpha feature gate HPAScaleToZero is enabled and at least one
	// Object or External metric is configured. Scaling is active as long as at
	// least one metric value is available.
	"minReplicas"?: int32 & int

	// reference to scaled resource; horizontal pod autoscaler will learn the
	// current resource consumption and will set the desired number of pods by
	// using its Scale subresource.
	"scaleTargetRef"!: #CrossVersionObjectReference

	// targetCPUUtilizationPercentage is the target average CPU utilization
	// (represented as a percentage of requested CPU) over all the pods; if not
	// specified the default autoscaling policy will be used.
	"targetCPUUtilizationPercentage"?: int32 & int
}

// current status of a horizontal pod autoscaler
#HorizontalPodAutoscalerStatus: {
	// currentCPUUtilizationPercentage is the current average CPU utilization over
	// all pods, represented as a percentage of requested CPU, e.g. 70 means that
	// an average pod is using now 70% of its requested CPU.
	"currentCPUUtilizationPercentage"?: int32 & int

	// currentReplicas is the current number of replicas of pods managed by this autoscaler.
	"currentReplicas"!: int32 & int

	// desiredReplicas is the desired number of replicas of pods managed by this autoscaler.
	"desiredReplicas"!: int32 & int

	// lastScaleTime is the last time the HorizontalPodAutoscaler scaled the number
	// of pods; used by the autoscaler to control how often the number of pods is
	// changed.
	"lastScaleTime"?: v1.#Time

	// observedGeneration is the most recent generation observed by this autoscaler.
	"observedGeneration"?: int64 & int
}

// Scale represents a scaling request for a resource.
#Scale: {
	// APIVersion defines the versioned schema of this representation of an object.
	// Servers should convert recognized schemas to the latest internal value, and
	// may reject unrecognized values. More info:
	// https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources
	"apiVersion": "autoscaling/v1"

	// Kind is a string value representing the REST resource this object represents.
	// Servers may infer this from the endpoint the client submits requests to.
	// Cannot be updated. In CamelCase. More info:
	// https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds
	"kind": "Scale"

	// Standard object metadata; More info:
	// https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata.
	"metadata"?: v1.#ObjectMeta

	// spec defines the behavior of the scale. More info:
	// https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#spec-and-status.
	"spec"?: #ScaleSpec

	// status is the current status of the scale. More info:
	// https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#spec-and-status.
	// Read-only.
	"status"?: #ScaleStatus
}

// ScaleSpec describes the attributes of a scale subresource.
#ScaleSpec: {
	// replicas is the desired number of instances for the scaled object.
	"replicas"?: int32 & int
}

// ScaleStatus represents the current status of a scale subresource.
#ScaleStatus: {
	// replicas is the actual number of observed instances of the scaled object.
	"replicas"!: int32 & int

	// selector is the label query over pods that should match the replicas count.
	// This is same as the label selector but in the string format to avoid
	// introspection by clients. The string will be in the same format as the
	// query-param syntax. More info about label selectors:
	// https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/
	"selector"?: string
}
