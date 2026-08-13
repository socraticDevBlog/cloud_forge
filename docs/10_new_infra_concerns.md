# new infrastructure concern

Note: make sure you read this before using this infrastructure codebase to provision and configure your server

## admin private key management

in order to make the virtual machine secure, we want to disable password authentication and only allow public key authentication

the drawback is that you are then obligated to manage your private key. Especially if you want to use more than one workstation - and even automation - to provision your infrastructure with terraform

advice: create a unique private key dedicated to your infrastructure. Safekeep it in a password manager like KeepassXC.

### sources

<https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_virtual_machine>

<https://security.stackexchange.com/questions/69407/why-is-using-an-ssh-key-more-secure-than-using-passwords>
