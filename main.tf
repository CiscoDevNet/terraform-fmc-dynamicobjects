terraform {
  required_providers {
    fmc = {
      source = "CiscoDevNet/fmc"
      version = "0.2.1"
    }
  }
}

locals {
  service_ids = transpose({
      for id, s in var.services : id => [s.name]
  })
  grouped = {
      for name, ids in local.service_ids:
      name => [
        for id in ids : var.services[id].address != "" ?
          "${var.services[id].address}" : "${var.services[id].node_address}"
      ]
  }
  svc = [
      for name, ids in local.grouped:
      name
      ]
}

data "fmc_dynamic_objects" "srv" {
  count = length(local.svc)
  name = "${local.svc[count.index]}"
}

resource "fmc_dynamic_object_mapping" "mapping" {
  for_each = local.grouped
  dynamic_object_id = data.fmc_dynamic_objects.srv[index(local.svc,each.key)].id
  mappings = each.value
}