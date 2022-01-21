# Cisco Secure Firewall Dynamic Objects module for Network Infrastructure Automation (NIA)

With shift to dynamic infrastructure, it becomes difficult for SecOps team to keep track of changes efficiently and dynamic firewalling becomes an important requirement. This Terraform module works in conjunction with Hashicorp's Consul to automate this requirement utilizing Cisco Secure Firewall **Dynamic Objects**.   

HashiCorp **Consul** is a service mesh solution providing a full featured control plane with service discovery, configuration, and segmentation functionality across several environments. Its service discovery feature allows Consul agents to register services to a central registry and other clients can use Consul to discover providers of a given service. It keeps track of all the services, the nodes on which these services are running and their health status. This information can be used to automate network and security tasks.

Network Infrastructure Automation (NIA) using **Consul-Terraform-Sync** enables dynamic updates to network infrastructure devices triggered by service changes. It  utilizes Consul as a data source that contains networking information about services, watches Consul state changes based on service health change, new instance registered/unregistered and forwards the data to a Terraform module that is automatically triggered. 
The automation task is executed with the most recent service variable values from the Consul service catalog. Each task consists of a runbook automation written as a Consul-Terraform-Sync compatible Terraform module using resources and data sources for the underlying network infrastructure allowing your day-2 operations to be constantly aligned with your application state and reduce manual ticketing processes.
[Please refer to this link for getting started with consul-terraform-sync](https://learn.hashicorp.com/tutorials/consul/consul-terraform-sync-intro?in=consul/network-infrastructure-automation)

This module manages **Dynamic objects** in **Cisco Secure Firewall Management Center (FMC)** to dynamically update values of objects that are applied as access rules to the firewall directly. Consul-Terraform-Sync forwards the updates for monitored services that it receives from Consul catalog, such as new nodes being registered, nodes being deregistered or nodes becoming unhealthy. This acts as input for the module which updates the dynamic objects present on FMC with the latest and updated list of IP addresses automatically. This module obtains object IDs from FMC based on the service name and updates the mappings for those objects accordingly.

<p align="left">
<img width="800" src=""> </a>
</p>

#### Note: This Terraform module is designed to be used only with consul-terraform-sync Feature

## This module supports the following:

* Create, update and delete **Dynamic object mappings** based on the changes in services in Consul catalog.

## Prerequisites:

The dynamic objects mapped to the services in Consul should be created on FMC with the same name as the service and applied in an access rule as per user's requirements before running consul-terraform-sync for the services.

## Requirements

| Name | Version |
|------|---------|
| terraform	| >= 0.13 |
| consul-terraform-sync	| >= 0.1.0 |
| consul	| >= 1.7 |

## Providers

| Name | Version |
|------|---------|
| fmc	| >= 0.2.1 |

## Usage

In order to use this module, you will need to install consul-terraform-sync, create a "task" with this Terraform module as a source within the task, subscribe to the services in the consul catalog and run consul-terraform-sync.

The Terraform module will be executed when there are any updates to the subscribed services.

**~> Note:** It is recommended to have the consul-terraform-sync config guide for reference.

1. Download and install the consul-terraform-sync following the download guide
2. Check the installation

```
$ consul-terraform-sync --version
consul-terraform-sync v0.4.2
Compatible with Terraform >= 0.13.0, < 1.1.0
```

3. Create a config file "tasks.hcl" for consul-terraform-sync. Please note that this just an example.

```
log_level = <log_level> # eg. "info"

driver "terraform" {
  required_providers {
    fmc = {
      source = "CiscoDevNet/fmc"
      version = "0.2.2"
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
```

4. Start consul-terraform-sync

```
$ consul-terraform-sync -config-file=tasks.hcl
```

consul-terraform-sync is now subscribed to the Consul catalog. Any updates to the serices identified in the task will result in updating the dynamic object mapping on Cisco FMC. The updates are fed as an input variable to the module.

## Inputs

| Name	 | Description	| Type	| Default	| Required |
|------|-------------|------|---------|:--------:|
| services	| Consul services monitored by consul-terraform-sync	| <pre>map(<br>    object({<br>      id        = string<br>      name      = string<br>      address   = string<br>      port      = number<br>      meta      = map(string)<br>      tags      = list(string)<br>      namespace = string<br>      status    = string<br><br>      node                  = string<br>      node_id               = string<br>      node_address          = string<br>      node_datacenter       = string<br>      node_tagged_addresses = map(string)<br>      node_meta             = map(string)<br>    })<br>  )</pre> | n/a | yes |


consul-terraform-sync creates a blocking API query session with the Consul agent indentified in the config to get updates from the Consul catalog. It gets an update for the services when any of the following service attributes are created, updated or deleted. These updates include service creation and deletion as well.

## Workflow

consul-terraform-sync will install the required version of Terraform.
consul-terraform-sync will install the required version of the Terraform provider defined in the config file and declared in the "task".
A new directory "sync-tasks" with a sub-directory corresponding to each "task" will be created.
Within each sub-directory corresponding a task, consul-terraform-sync will create main.tf, variables.tf, providers.tfvars, terraform.tfvars and terraform.tfvars.tmpl files.

* **main.tf:**

This file contains declaration for the required terraform and provider versions based on the task definition.
In addition, this file has the module (identified by the 'source' field in the task) declaration with the input variables

example generated main.tf:
```terraform
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
      version = "0.2.2"
    }
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
  source   = "CiscoDevnet/terraform-fmc-dynamicobject"
  services = var.services
}
```
 * **variables.tf:**

This is variables.tf file defined in the module

example generated variables.tf
```terraform
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
```

* **providers.tfvars:**
* This file contains the values for the variables that are used to define the providers in the task.

* **terraform.tfvars:**
* This is the most important file generated by consul-terraform-sync.
* This variables file is generated with the most updated values from Consul catalog for all the services identified in the task.
* consul-terraform-sync updates this file with the latest values when the corresponding service gets updated in Consul catalog.

consul-terraform-sync manages the entire Terraform workflow of plan, apply and destroy for all the individual workspaces corresponding to the defined "tasks" based on the updates to the services to those tasks.

If there is a missing feature or a bug - - open an issue
