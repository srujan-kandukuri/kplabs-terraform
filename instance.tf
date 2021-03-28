
#Below resource is to create public key

resource "tls_private_key" "sskeygen_execution" {
  algorithm = "RSA"
  rsa_bits  = 4096
}


# Below are the aws key pair
resource "aws_key_pair" "prometheus_key_pair" {
  depends_on = ["tls_private_key.sskeygen_execution"]
  key_name   = var.aws_public_key_name
  public_key = tls_private_key.sskeygen_execution.public_key_openssh
}


# prometheus instance
resource "aws_instance" "prometheus_instance" {
  ami               = "ami-09135e71dc2619458"#"ami-0823b5cf95e3271bd"#"${lookup(var.aws_amis, var.aws_region)}"
  instance_type     = var.aws_instance_type
  availability_zone =  "us-east-2a"#var.aws_availability_zone
  associate_public_ip_address = true
  key_name               =  aws_key_pair.prometheus_key_pair.key_name
  vpc_security_group_ids = ["${aws_security_group.prometheus_security_group.id}"]
  subnet_id              = "subnet-0ec7f6f0c0fd1919b"
  connection {
    user        = "ubuntu"
    host = self.public_ip
    private_key = tls_private_key.sskeygen_execution.private_key_pem
  }

# Copy the prometheus file to instance
  provisioner "file" {
    source      = "./prometheus.yml"
    destination = "/tmp/prometheus.yml"
  }
 provisioner "local-exec" {
    command = "echo '${tls_private_key.sskeygen_execution.private_key_pem}' >> ${aws_key_pair.prometheus_key_pair.id}.pem "
  }

# Install docker in the ubuntu
  provisioner "remote-exec" {
    inline = [
      "sudo apt update",
      "sudo apt -y install apt-transport-https ca-certificates curl software-properties-common",
      "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -",
      "sudo add-apt-repository 'deb [arch=amd64] https://download.docker.com/linux/ubuntu bionic stable'",
      "sudo apt update",
      "sudo apt -y install docker-ce",
      "sudo mkdir /prometheus-data",
      "sudo cp /tmp/prometheus.yml /prometheus-data/.",
      "sudo sed -i 's;<access_key>;${aws_iam_access_key.prometheus_access_key.id};g' /prometheus-data/prometheus.yml",
      "sudo sed -i 's;<secret_key>;${aws_iam_access_key.prometheus_access_key.secret};g' /prometheus-data/prometheus.yml",
      "sudo docker run -d -p 9090:9090 --name=prometheus -v /prometheus-data/prometheus.yml:/etc/prometheus/prometheus.yml prom/prometheus",
      "sudo docker run -d -p 3000:3000 --name=grafana grafana/grafana"

    ]
  }
  #provisioner "local-exec" {
    #command = "echo '${tls_private_key.sskeygen_execution.private_key_pem}' >> ${aws_key_pair.prometheus_key_pair.id}.pem ;  chmod 400 ${aws_key_pair.prometheus_key_pair.id}.pem"

  tags = {
    Name = "${var.name}_instance"
    Environment = "${var.env}"
  }
}

