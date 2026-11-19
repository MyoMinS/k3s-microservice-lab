variable "kubeconfig_path" {
  type        = string
  description = "Absolute path to the local kubeconfig copied from the EC2 host."
  validation {
    condition     = fileexists(var.kubeconfig_path)
    error_message = "Copy the EC2 kubeconfig locally before applying add-ons."
  }
}