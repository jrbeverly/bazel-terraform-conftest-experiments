# Experimenting with ConfTest, Terraform & Bazel

Experimenting with using Bazel to handle the build & execution of Terraform files, while providing means of writing tests against the terraform with conftest. Fiddling with the idea of having local tests against the configuration, as well as tests against the terraform plan.

The intention is that Bazel would be responsible for constructing Terraform deployable tarballs, which contains all resolved modules & providers. These would be executed to perform `apply`, `plan` and other commands. 

# Notes

- Terraform init should be treated as a repository rule, based off the `.terraform.lock.hcl`
- Modules can exist in any directory, and be substituted into other packages as its using the `pkg_tar` under the hood
- Using a provider to keep track of "runpaths" for any of the commands, making it so these properties can be shared across rules
- Substitutions in command arguments through `{variable}` and kwargs works great
- Standard pattern for "chaining" commands is needed, so that running one will run the others
- Should it always be the case that Terraform does a `plan` then `apply`?
- How should chained commands perform some degree of caching so they aren't re-running every single time?
- Terraform modules need to exist in multiple forms: local modules & externally sourced modules (e.g. how to integrate with `http_archive` - or similar)
- Using the pattern of custom rules under `bazel/rules/rules_xyz` is really nice, the `deps.bzl` can then just load them
- Rego/OPA are missing vscode extensions for use in gitpod (does vscode have them in devcontainers?)
- Adding the `opa` toolchain along with the testing process went really well
- Long term `rules_toolchains` should be external, and rely on a pre-installed tool like `toolchains` or `termtools`, that can download these
- How do these rules integrate with different kinds of rules? Is the API solid enough that something like `rules_terraform_ext` could be made to provide common helpers?
- Should the `terraform_workspace` really exist? Or should it just be `terraform_command` with something like `rules_terraform_ext` filling in the ease-of-use?
- Makefile with bazel can be great for the `make help` addition
