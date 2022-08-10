resource "aws_instance" "instance" {
  instance_type    = "t3.small"
  ami              = data.aws_ami.main.image_id
  vpc_security_group_ids = [aws_security_group.main.id]

  tags = {
    Name           = local.TAG_PREFIX
  }
}

resource "null_resource" "copy-local-artifact" {
  triggers = {
    abc    = timestamp()
  }
  provisioner "file" {
    connection {
      user     = jsondecode(data.aws_secretsmanager_secret_version.secret.secret_string)["SSH_USER"]
      password = jsondecode(data.aws_secretsmanager_secret_version.secret.secret_string)["SSH_PASS"]
      host     = aws_instance.instance.private_ip
      }
    source      = "${var.COMPONENT}-${var.APP_VERSION}.zip"
    destination = "/tmp/${var.COMPONENT}.zip"
    }
  }


resource "null_resource" "ansible" {
  depends_on = [null_resource.copy-local-artifact]
  provisioner "remote-exec" {
    connection {
      user     = jsondecode(data.aws_secretsmanager_secret_version.secret.secret_string)["SSH_USER"]
      password = jsondecode(data.aws_secretsmanager_secret_version.secret.secret_string)["SSH_PASS"]
      host     = aws_instance.instance.private_ip
    }
    inline = [
      "ansible-pull -U https://github.com/devopsravi9/roboshop-ansible.git roboshop.yml -e HOST=localhost -e ROLE=${var.COMPONENT} -e ENV=ENV -e DOCDB_ENDPOINT=DOCDB_ENDPOINT -e REDDIS_ENDPOINT=REDDIS_ENDPOINT -e MYSQL_ENDPOINT=MYSQL_ENDPOINT"
    ]
  }
}