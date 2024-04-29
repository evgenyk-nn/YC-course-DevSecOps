resource "yandex_kubernetes_cluster" "k8s-master" {

  name        = "k8s-master"
  description = "k8s master"

  network_id = yandex_vpc_network.k8s-network.id
  master {
    version = "1.21"
    zonal {
      zone      = yandex_vpc_subnet.k8s-subnet.zone
      subnet_id = yandex_vpc_subnet.k8s-subnet.id
    }
    public_ip = true
  }

  service_account_id      = yandex_iam_service_account.k8s-sa.id
  node_service_account_id = yandex_iam_service_account.k8s-sa.id
  depends_on = [
    yandex_resourcemanager_folder_iam_binding.editor,
    yandex_resourcemanager_folder_iam_binding.images-puller
  ]
}

resource "yandex_kubernetes_node_group" "k8s_node_group" {
  cluster_id  = yandex_kubernetes_cluster.k8s-master.id
  name        = "k8s-node-group"
  description = "k8s node"
  version     = "1.21"

  instance_template {
    platform_id = "standard-v2"

    network_interface {
      nat        = true
      subnet_ids = ["${yandex_vpc_subnet.k8s-subnet.id}"]
    }

    resources {
      memory = 4
      cores  = 4
    }

    boot_disk {
      type = "network-ssd"
      size = 64
    }

    scheduling_policy {
      preemptible = false
    }

    container_runtime {
      type = "containerd"
    }
  }

  scale_policy {
    fixed_scale {
      size = 1
    }
  }

  allocation_policy {
    location {
      zone = "ru-central1-a"
    }
  }
}

resource "yandex_vpc_network" "k8s-network" { name = "k8s-network" }

resource "yandex_vpc_subnet" "k8s-subnet" {
  v4_cidr_blocks = ["10.200.0.0/16"]
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.k8s-network.id
}

resource "yandex_iam_service_account" "k8s-sa" {
  name        = "k8s-sa"
  description = "k8s iam service account"
}

resource "yandex_resourcemanager_folder_iam_binding" "editor" {
  # Сервисному аккаунту назначается роль "editor".
  folder_id = "b1gvgjvpun18eqkkop1k"
  role      = "editor"
  members = [
    "serviceAccount:${yandex_iam_service_account.k8s-sa.id}"
  ]
}

resource "yandex_resourcemanager_folder_iam_binding" "images-puller" {
  # Сервисному аккаунту назначается роль "container-registry.images.puller".
  folder_id = "b1gvgjvpun18eqkkop1k"
  role      = "container-registry.images.puller"
  members = [
    "serviceAccount:${yandex_iam_service_account.k8s-sa.id}"
  ]
}