package policy

type Operation string

const (
	List   Operation = "list"
	Reveal Operation = "reveal"
	Create Operation = "create"
	Update Operation = "update"
	Delete Operation = "delete"
)

func Valid(operation Operation) bool {
	switch operation {
	case List, Reveal, Create, Update, Delete:
		return true
	default:
		return false
	}
}
