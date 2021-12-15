#Cisco Secure Firewall Dynamic Objects module for Network Infrastructure Automation (NIA)

This Terraform module allows users to support Dynamic Firewalling by integrating Consul with Cisco Secure Firewall Management Ceneter allowing policies to be updated dynamically based on services in Consul mapped to virtual machines which are updated as and when new machines come up or terminated as per requirement. 
This module will serve as a source for consul-terraform-sync which works in conjunction with consul to update Dynamic objects on Cisco FMC based on changes detected on services in consul which consul-terraform-sync monitors.

**Note: This Terraform module is designed to be used only with consul-terraform-sync Feature**

##Prerequisites:

The dynamic object mapped to the service in Consul should be configured on FMC before using the service in consul-terraform-sync

This module supports the following:

* Create, update and delete Dynamic object mappings based on the changes in services in Consul catalog.

If there is a missing feature or a bug - - open an issue

##What is consul-terraform-sync?
The consul-terraform-sync runs as a daemon that enables a publisher-subscriber paradigm between Consul and Cisco Secure FMC to support Network Infrastructure Automation (NIA).


consul-terraform-sync subscribes to updates from the Consul catalog and executes one or more automation "tasks" with appropriate value of service variables based on those updates. consul-terraform-sync leverages Terraform as the underlying automation tool and utilizes the Terraform provider ecosystem to drive relevant change to the network infrastructure.

Each task consists of a runbook automation written as a compatible Terraform module using resources and data sources for the underlying network infrastructure provider.

Please refer to this link for getting started with consul-terraform-sync

'''
Requirements
Name	Version
terraform	>= 0.13
consul-terraform-sync	>= 0.1.0
consul	>= 1.7
Providers
Name	Version
fmc	>= 0.2.1
Compatibility
This module is meant for use with consul-terraform-sync >= 0.1.0 and Terraform >= 0.13 and fmc versions >= 0.2.1
'''

Usage
In order to use this module, you will need to install consul-terraform-sync, create a "task" with this Terraform module as a source within the task, and run consul-terraform-sync.

The users can subscribe to the services in the consul catalog and define the Terraform module which will be executed when there are any updates to the subscribed services using a "task".

~> Note: It is recommended to have the consul-terraform-sync config guide for reference.

Download the consul-terraform-sync on a node which is highly available (prefrably, a node running a consul client)
Add consul-terraform-sync to the PATH on that node
Check the installation
 $ consul-terraform-sync --version
consul-terraform-sync v0.4.2
Compatible with Terraform >= 0.13.0, < 1.1.0

Create a config file "tasks.hcl" for consul-terraform-sync. Please note that this just an example.
log_level = <log_level> # eg. "info"

driver "terraform" {
  required_providers {
    fmc = {
      source = "CiscoDevNet/fmc"
      version = "0.2.1"
    }
  }
}

consul {
  address = "<consul agent address>" # eg. "1.1.1.1:8500"
}

terraform_provider "fmc" {
  fmc_username = <fmc_username>
  fmc_password = <fmc_password>
  fmc_host = <fmc_host>
  fmc_insecure_skip_verify = false
}

task {
  name = <name of the task (has to be unique)> # eg. "Create Dynamic Object Mappings"
  description = <description of the task> # eg. "Update Dynamic object mappings on FMC based on consul service updates"
  source = "CiscoDevnet/terraform-fmc-dynamicobject" # to be updated
  providers = ["fmc"]
  services = ["<list of services you want to subscribe to>"] # eg. ["web", "api"]
  variable_files = ["<list of files that have user variables for this module (please input full path)>"] # eg. ["terraform.tfvars"]
}

Start consul-terraform-sync
$ consul-terraform-sync -config-file=tasks.hcl
consul-terraform-sync will update Dynamic object mappings on FMC based on service updates in consul catalog.

consul-terraform-sync is now subscribed to the Consul catalog. Any updates to the serices identified in the task will result in updating the dynamic object mapping on Cisco FMC

~> Note: If you are interested in how consul-terraform-sync works, please refer to this section.

Inputs
Name	Description	Type	Default	Required
services	Consul services monitored by consul-terraform-sync	
map(
    object({
      id        = string
      name      = string
      address   = string
      port      = number
      meta      = map(string)
      tags      = list(string)
      namespace = string
      status    = string

      node                  = string
      node_id               = string
      node_address          = string
      node_datacenter       = string
      node_tagged_addresses = map(string)
      node_meta             = map(string)
    })
  )

Outputs
Name	Description

How does consul-terraform-sync work?
There are 2 aspects of consul-terraform-sync.

Updates from Consul catalog: In the backend, consul-terraform-sync creates a blocking API query session with the Consul agent indentified in the config to get updates from the Consul catalog. consul-terraform-sync. consul-terraform-sync will get an update for the services in the consul catalog when any of the following service attributes are created, updated or deleted. These updates include service creation and deletion as well.

service id
service name
service address
service port
service meta
service tags
service namespace
service health status
node id
node address
node datacenter
node tagged addresses
node meta

Managing the entire Terraform workflow: If a task and is defined, one or more services are associated with the task, provider is declared in the task and a Terraform module is specified using the source field of the task, the following sequence of events will occur:

consul-terraform-sync will install the required version of Terraform.
consul-terraform-sync will install the required version of the Terraform provider defined in the config file and declared in the "task".
A new direstory "sync-tasks" with a sub-directory corresponding to each "task" will be created. This is the reason for having strict guidelines around naming.
Each sub-directory corresponds to a separate Terraform workspace.
Within each sub-directory corresponding a task, consul-terraform-sync will template a main.tf, variables.tf, terraform.tfvars and terraform.tfvars.tmpl.

main.tf:

This file contains declaration for the required terraform and provider versions based on the task definition.
In addition, this file has the module (identified by the 'source' field in the task) declaration with the input variables
Consul K/V is used as the backend state for fo this Terraform workspace.
example generated main.tf:

# This file is generated by Consul NIA.
#
# The HCL blocks, arguments, variables, and values are derived from the
# operator configuration for Consul NIA. Any manual changes to this file
# may not be preserved and could be clobbered by a subsequent update.

terraform {
  required_version = ">= 0.13.0, < 1.1.0"
  required_providers {
    fmc = {
      source  = "CiscoDevNet/fmc"
      version = "0.2.1"
    }
  }
  backend "local" {
    path = "/Users/sameersingh/git_repos/consul-fmc-dynamicobjects/terraform.tfstate"
  }
}

provider "fmc" {
  fmc_host                 = var.fmc.fmc_host
  fmc_insecure_skip_verify = var.fmc.fmc_insecure_skip_verify
  fmc_password             = var.fmc.fmc_password
  fmc_username             = var.fmc.fmc_username
}

# update policies based on node availability
module "web" {
  source   = "/Users/sameersingh/git_repos/terraform-fmc-dynamicobject"
  services = var.services
}

variables.tf:

This is variables.tf file defined in the module
example generated variables.tf

variable "services" {
description = "Consul services monitored by Consul NIA"
  type = map(
    object({
      id        = string
      name      = string
      address   = string
      port      = number
      status    = string
      meta      = map(string)
      tags      = list(string)
      namespace = string

      node                  = string
      node_id               = string
      node_address          = string
      node_datacenter       = string
      node_tagged_addresses = map(string)
      node_meta             = map(string)
    })
  )
}


terraform.tfvars:

This is the most important file generated by consul-terraform-sync.
This variables file is generated with the most updated values from Consul catalog for all the services identified in the task.
consul-terraform-sync updates this file with the latest values when the corresponding service gets updated in Consul catalog.

Network Infrastructure Automation (NIA) compatible modules are built to utilize the above service variables

consul-terraform-sync manages the entire Terraform workflow of plan, apply and destroy for all the individual workspaces corrresponding to the defined "tasks" based on the updates to the services to those tasks.
In summary, consul-terraform-sync triggers a Terraform workflow (plan, apply, destroy) based on updates it detects from Consul catalog.
