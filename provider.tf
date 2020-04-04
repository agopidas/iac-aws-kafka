provider "aws" {
  region     = "us-east-1"
}

resource "aws_vpc" "kafka_home_tf_vpc" {
    cidr_block = "190.160.0.0/16"
    instance_tenancy = "default"
    tags = {
        Name = "main"
        Location="nyc"
    }
}

resource "aws_subnet" "subnet1" {
    vpc_id= aws_vpc.kafka_home_tf_vpc.id
    cidr_block="190.160.1.0/24"

    tags = {
        Name="Subnet1"
    }
  
}

resource "aws_internet_gateway" "main" {
    vpc_id=aws_vpc.kafka_home_tf_vpc.id
}

resource "aws_route_table" "default" {
    vpc_id = aws_vpc.kafka_home_tf_vpc.id
    route{
        cidr_block="0.0.0.0/0"
        gateway_id= aws_internet_gateway.main.id
    }
  
}

resource "aws_route_table_association" "main"{
    subnet_id= aws_subnet.subnet1.id
    route_table_id =  aws_route_table.default.id
}

resource "aws_network_acl" "allowall" {
    vpc_id = aws_vpc.kafka_home_tf_vpc.id
    egress{
        protocol ="-1"
        rule_no = 100
        action = "allow"
        cidr_block = "0.0.0.0/0"
        from_port = 0
        to_port = 0
    }
    ingress {
        protocol ="-1"
        rule_no = 200
        action = "allow"
        cidr_block = "0.0.0.0/0"
        from_port = 0
        to_port = 0
    }
}

resource "aws_security_group" "allowall" {
    name = "Terraform EC2 Allow All"
    description = "Allows all traffic" //Am crazy
    vpc_id = aws_vpc.kafka_home_tf_vpc.id

    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_eip" "webserver" {
    instance = aws_instance.webserver.id
    vpc = true
    depends_on = [aws_internet_gateway.main]
}

resource "aws_key_pair" "default" {
    key_name = "tf_ssh_key"
    public_key ="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDAuGQ1fWJ63dort9cdzgaLlXGBGjZG9cP8/pihjKO8mlOyGgPYeumNyMYi5iaBOGG3YEvxvWbPrcu0JguowVMl92U1tvF89svgxXKcGBYb/KZtGGqDlf7Jb+m5EHOzRAu2xEINiSSRiGJ5FZnaP6GXOKynsRqebtpUNA1UohhZzCBwaC+1qvKjsRnGGwD0BUZKmLHvOp1zvucwzfTSqUCTqp+Otrp/Ek+VunllLY9jyXhwNam7F6i2cd/E15NxPjcyBw89XH990iDooAOABpwkTw6ZCAxSRtsQWRV9E8HzTPg30J9wMjLYmOjVabZZjDx5aAsG4ZC90jp44aYME8zAhqyjdygGUdmSwqoDZHlidpTbAwqZQ9e4VXawDXTyh6aiiqPQY1twn1y6UY9qNMZXDFf01uLp+/jjQJ+sk1NCvahP6VMVBoyaN+IGJsiMk9p792WOFoxMES3/OyujWHD+//f2anfymccbYZJsrVL68xxl4tlwGLhBiaz9UnPBU+MgDRbvtH6AbmegZojBzEr/5mTGNEWzX8V8YSf1rTXzvgECxjjSv8z7YMadXjmFvivU218MkTGQOkf0ejmelh5r1dE6x69xAuHMuhLFn+wppsO8OsI70CGfRt0u2PlS0tAVbrdvFjrLzfaPCLXF8gTd4e1PzMPzRTD9ySK4TPukdQ== agopidas@gmail.com"
}

data "aws_ami" "ubuntu-18_04" {
    most_recent = true

    filter {
        name = "name"
        values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
    }

    filter {
        name = "virtualization-type"
        values = ["hvm"]
    }

    owners = ["099720109477"] # Canonical who maintains Ubuntu
}

resource "aws_instance" "webserver" {
    ami = data.aws_ami.ubuntu-18_04.id
    availability_zone = "us-east-1c"
    instance_type = "t2.large"
    key_name = aws_key_pair.default.key_name
    vpc_security_group_ids = [aws_security_group.allowall.id]
    subnet_id= aws_subnet.subnet1.id
}

output "public_ip" {
    value = aws_eip.webserver.public_ip
}