# ansible-terraform-azure-example
Example repository that allows a small VM cluster to be provisioned on Azure through Terraform, and then deploy a small app with Ansible.
#

## Requirements:
- [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html)
- [Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli)
- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)


## How to provision the VMs on Azure:
1. Login to Azure by running `azure login`
2. Edit the `terraform.tfvars` file accordingly.
3. Prepare Terraform by running `terraform init`
4. Confirm the plan is correct by running `terraform plan`
5. Finally, run `terraform apply` to provision the infrastructure.

## How to deploy the app with Ansible:
1. Update the inventory files with the target hosts accordingly.

    1.1. The Terraform script will create a file called `inventory` which has the required information to deploy to the Azure cluster.

2. Run the following command:
    
    ```
    ansible-playbook webservers.yml -i <inventory file>
    ```
