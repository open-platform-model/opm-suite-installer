package v1

import "cue.dev/x/k8s.io/apimachinery/pkg/apis/meta/v1"

// AggregationRule describes how to locate ClusterRoles to aggregate into the ClusterRole
#AggregationRule: {
	// ClusterRoleSelectors holds a list of selectors which will be used to find
	// ClusterRoles and create the rules. If any of the selectors match, then the
	// ClusterRole's permissions will be added
	"clusterRoleSelectors"?: [...v1.#LabelSelector]
}

// ClusterRole is a cluster level, logical grouping of PolicyRules that can be
// referenced as a unit by a RoleBinding or ClusterRoleBinding.
#ClusterRole: {
	// AggregationRule is an optional field that describes how to build the Rules
	// for this ClusterRole. If AggregationRule is set, then the Rules are
	// controller managed and direct changes to Rules will be stomped by the
	// controller.
	"aggregationRule"?: #AggregationRule

	// APIVersion defines the versioned schema of this representation of an object.
	// Servers should convert recognized schemas to the latest internal value, and
	// may reject unrecognized values. More info:
	// https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources
	"apiVersion": "rbac.authorization.k8s.io/v1"

	// Kind is a string value representing the REST resource this object represents.
	// Servers may infer this from the endpoint the client submits requests to.
	// Cannot be updated. In CamelCase. More info:
	// https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds
	"kind": "ClusterRole"

	// Standard object's metadata.
	"metadata"?: v1.#ObjectMeta

	// Rules holds all the PolicyRules for this ClusterRole
	"rules"?: [...#PolicyRule]
}

// ClusterRoleBinding references a ClusterRole, but not contain it. It can
// reference a ClusterRole in the global namespace, and adds who information
// via Subject.
#ClusterRoleBinding: {
	// APIVersion defines the versioned schema of this representation of an object.
	// Servers should convert recognized schemas to the latest internal value, and
	// may reject unrecognized values. More info:
	// https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources
	"apiVersion": "rbac.authorization.k8s.io/v1"

	// Kind is a string value representing the REST resource this object represents.
	// Servers may infer this from the endpoint the client submits requests to.
	// Cannot be updated. In CamelCase. More info:
	// https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds
	"kind": "ClusterRoleBinding"

	// Standard object's metadata.
	"metadata"?: v1.#ObjectMeta

	// RoleRef can only reference a ClusterRole in the global namespace. If the
	// RoleRef cannot be resolved, the Authorizer must return an error. This field
	// is immutable.
	"roleRef"!: #RoleRef

	// Subjects holds references to the objects the role applies to.
	"subjects"?: [...#Subject]
}

// ClusterRoleBindingList is a collection of ClusterRoleBindings
#ClusterRoleBindingList: {
	// APIVersion defines the versioned schema of this representation of an object.
	// Servers should convert recognized schemas to the latest internal value, and
	// may reject unrecognized values. More info:
	// https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources
	"apiVersion": "rbac.authorization.k8s.io/v1"

	// Items is a list of ClusterRoleBindings
	"items"!: [...#ClusterRoleBinding]

	// Kind is a string value representing the REST resource this object represents.
	// Servers may infer this from the endpoint the client submits requests to.
	// Cannot be updated. In CamelCase. More info:
	// https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds
	"kind": "ClusterRoleBindingList"

	// Standard object's metadata.
	"metadata"?: v1.#ListMeta
}

// ClusterRoleList is a collection of ClusterRoles
#ClusterRoleList: {
	// APIVersion defines the versioned schema of this representation of an object.
	// Servers should convert recognized schemas to the latest internal value, and
	// may reject unrecognized values. More info:
	// https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources
	"apiVersion": "rbac.authorization.k8s.io/v1"

	// Items is a list of ClusterRoles
	"items"!: [...#ClusterRole]

	// Kind is a string value representing the REST resource this object represents.
	// Servers may infer this from the endpoint the client submits requests to.
	// Cannot be updated. In CamelCase. More info:
	// https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds
	"kind": "ClusterRoleList"

	// Standard object's metadata.
	"metadata"?: v1.#ListMeta
}

// PolicyRule holds information that describes a policy rule, but does not
// contain information about who the rule applies to or which namespace the
// rule applies to.
#PolicyRule: {
	// APIGroups is the name of the APIGroup that contains the resources. If
	// multiple API groups are specified, any action requested against one of the
	// enumerated resources in any API group will be allowed. "" represents the
	// core API group and "*" represents all API groups.
	"apiGroups"?: [...string]

	// NonResourceURLs is a set of partial urls that a user should have access to.
	// *s are allowed, but only as the full, final step in the path Since
	// non-resource URLs are not namespaced, this field is only applicable for
	// ClusterRoles referenced from a ClusterRoleBinding. Rules can either apply to
	// API resources (such as "pods" or "secrets") or non-resource URL paths (such
	// as "/api"), but not both.
	"nonResourceURLs"?: [...string]

	// ResourceNames is an optional white list of names that the rule applies to. An
	// empty set means that everything is allowed.
	"resourceNames"?: [...string]

	// Resources is a list of resources this rule applies to. '*' represents all resources.
	"resources"?: [...string]

	// Verbs is a list of Verbs that apply to ALL the ResourceKinds contained in
	// this rule. '*' represents all verbs.
	"verbs"!: [...string]
}

// Role is a namespaced, logical grouping of PolicyRules that can be referenced
// as a unit by a RoleBinding.
#Role: {
	// APIVersion defines the versioned schema of this representation of an object.
	// Servers should convert recognized schemas to the latest internal value, and
	// may reject unrecognized values. More info:
	// https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources
	"apiVersion": "rbac.authorization.k8s.io/v1"

	// Kind is a string value representing the REST resource this object represents.
	// Servers may infer this from the endpoint the client submits requests to.
	// Cannot be updated. In CamelCase. More info:
	// https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds
	"kind": "Role"

	// Standard object's metadata.
	"metadata"?: v1.#ObjectMeta

	// Rules holds all the PolicyRules for this Role
	"rules"?: [...#PolicyRule]
}

// RoleBinding references a role, but does not contain it. It can reference a
// Role in the same namespace or a ClusterRole in the global namespace. It adds
// who information via Subjects and namespace information by which namespace it
// exists in. RoleBindings in a given namespace only have effect in that
// namespace.
#RoleBinding: {
	// APIVersion defines the versioned schema of this representation of an object.
	// Servers should convert recognized schemas to the latest internal value, and
	// may reject unrecognized values. More info:
	// https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources
	"apiVersion": "rbac.authorization.k8s.io/v1"

	// Kind is a string value representing the REST resource this object represents.
	// Servers may infer this from the endpoint the client submits requests to.
	// Cannot be updated. In CamelCase. More info:
	// https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds
	"kind": "RoleBinding"

	// Standard object's metadata.
	"metadata"?: v1.#ObjectMeta

	// RoleRef can reference a Role in the current namespace or a ClusterRole in the
	// global namespace. If the RoleRef cannot be resolved, the Authorizer must
	// return an error. This field is immutable.
	"roleRef"!: #RoleRef

	// Subjects holds references to the objects the role applies to.
	"subjects"?: [...#Subject]
}

// RoleBindingList is a collection of RoleBindings
#RoleBindingList: {
	// APIVersion defines the versioned schema of this representation of an object.
	// Servers should convert recognized schemas to the latest internal value, and
	// may reject unrecognized values. More info:
	// https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources
	"apiVersion": "rbac.authorization.k8s.io/v1"

	// Items is a list of RoleBindings
	"items"!: [...#RoleBinding]

	// Kind is a string value representing the REST resource this object represents.
	// Servers may infer this from the endpoint the client submits requests to.
	// Cannot be updated. In CamelCase. More info:
	// https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds
	"kind": "RoleBindingList"

	// Standard object's metadata.
	"metadata"?: v1.#ListMeta
}

// RoleList is a collection of Roles
#RoleList: {
	// APIVersion defines the versioned schema of this representation of an object.
	// Servers should convert recognized schemas to the latest internal value, and
	// may reject unrecognized values. More info:
	// https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources
	"apiVersion": "rbac.authorization.k8s.io/v1"

	// Items is a list of Roles
	"items"!: [...#Role]

	// Kind is a string value representing the REST resource this object represents.
	// Servers may infer this from the endpoint the client submits requests to.
	// Cannot be updated. In CamelCase. More info:
	// https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds
	"kind": "RoleList"

	// Standard object's metadata.
	"metadata"?: v1.#ListMeta
}

// RoleRef contains information that points to the role being used
#RoleRef: {
	// APIGroup is the group for the resource being referenced
	"apiGroup"?: string

	// Kind is the type of resource being referenced
	"kind"!: string

	// Name is the name of resource being referenced
	"name"!: string
}

// Subject contains a reference to the object or user identities a role binding
// applies to. This can either hold a direct API object reference, or a value
// for non-objects such as user and group names.
#Subject: {
	// APIGroup holds the API group of the referenced subject. Defaults to "" for
	// ServiceAccount subjects. Defaults to "rbac.authorization.k8s.io" for User
	// and Group subjects.
	"apiGroup"?: string

	// Kind of object being referenced. Values defined by this API group are "User",
	// "Group", and "ServiceAccount". If the Authorizer does not recognized the
	// kind value, the Authorizer should report an error.
	"kind"!: string

	// Name of the object being referenced.
	"name"!: string

	// Namespace of the referenced object. If the object kind is non-namespace, such
	// as "User" or "Group", and this value is not empty the Authorizer should
	// report an error.
	"namespace"?: string
}
