#All AWS infrastructure will be in this file

#Provider AWS region us-east-1 access&secret keys from variables.tf

provider "aws" {
	access_key = "${var.access_key}"
	secret_key = "${var.secret_key}"
	region	   = "us-east-1"
}

#Create VPC 

resource "aws_vpc" "vpc" {
	cidr_block        = "10.0.0.0/16"
    
	tags = {
        	Name = "vpc"
   		}
}


#Create Subnet #1

resource "aws_subnet" "subnet1" {
 	 vpc_id           	 = aws_vpc.vpc.id
 	 cidr_block      	 = "10.0.16.0/20"
 	 availability_zone 	 = "us-east-1a"
	 map_public_ip_on_launch = true

 	 tags = {
   		 Name = "subnet1"
  		 }
}

#Create Subnet #2

resource "aws_subnet" "subnet2" {
	vpc_id          	 = aws_vpc.vpc.id
	cidr_block       	 = "10.0.32.0/20"
	availability_zone	 = "us-east-1b"
	map_public_ip_on_launch = true

	tags = {
   		Name = "subnet2"
  		}
}

#Create DB_subnet #1

resource "aws_subnet" "db_subnet1" {
 	 vpc_id           	 = aws_vpc.vpc.id
 	 cidr_block      	 = "10.0.48.0/20"
 	 availability_zone 	 = "us-east-1a"

 	 tags = {
   		 Name = "DB_subnet1"
  		 }
}

#Create DB_subnet #2

resource "aws_subnet" "db_subnet2" {
	vpc_id          	 = aws_vpc.vpc.id
	cidr_block       	 = "10.0.64.0/20"
	availability_zone	 = "us-east-1b"

	tags = {
   		Name = "DB_subnet2"
  		}
}

#Create DB_Subnet_Group

resource "aws_db_subnet_group" "db_subnet_group" {
 	 name       = "db_subnet_group"
 	 subnet_ids = [aws_subnet.db_subnet1.id, aws_subnet.db_subnet2.id]

	  tags = {
  	  Name = "DB subnet group"
 	 }
}

#Create GW

resource "aws_internet_gateway" "gw" {
 	 vpc_id = aws_vpc.vpc.id

 	 tags = {
 	   Name = "vpc_gw"
 	  }
}

#Create Route Table

resource "aws_route_table" "rt" {
 	 vpc_id = aws_vpc.vpc.id
	route {
  	  cidr_block = "0.0.0.0/0"
 	  gateway_id = aws_internet_gateway.gw.id
 	  }

	tags = {
 	   Name = "route table"
	   }
}

#Connect between RT to Subnets

resource "aws_route_table_association" "rt_connect1" {
 	 subnet_id      = aws_subnet.subnet1.id
	 route_table_id = aws_route_table.rt.id
}
resource "aws_route_table_association" "rt_connect2" {
 	 subnet_id      = aws_subnet.subnet2.id
	 route_table_id = aws_route_table.rt.id
}


#Create EC2 #1

resource "aws_instance" "EC2-1" {
	ami				= "ami-04505e74c0741db8d"
	instance_type			= "t2.micro"
	availability_zone 		= "us-east-1a"
	subnet_id   			= aws_subnet.subnet1.id
	security_groups		= [aws_security_group.sg.id]

	#Shell Script install apache

	user_data = <<-EOF
 	 #!/bin/bash
 	 echo "*** Installing apache2"
 	 sudo apt update -y
 	 sudo apt install apache2 -y
 	 echo "*** Completed Installing apache2"
  	EOF

	tags = {
		Name = "Ubuntu Server-1"
		} 
}

#Create EC2 #2

resource "aws_instance" "EC2-2" {
       ami            		= "ami-04505e74c0741db8d"
       instance_type  		= "t2.micro"
	availability_zone 		= "us-east-1b"
	subnet_id   			= aws_subnet.subnet2.id
	security_groups		= [aws_security_group.sg.id]

	#Shell Script install apache

	user_data = <<-EOF
 	 #!/bin/bash
 	 echo "*** Installing apache2"
 	 sudo apt update -y
 	 sudo apt install apache2 -y
 	 echo "*** Completed Installing apache2"
  	EOF


	tags = {
                Name = "Ubuntu Server-2"
                }
}

#Create PostgreSQL RDS

resource "aws_db_instance" "RDS" {
       allocated_storage 	= 100
	identifier 	  	= "rds-instance"
	engine		  	= "Postgres"
	engine_version	 	= "13.4"
	instance_class 		= "db.m5.large"
	username 		= "postgres"
	password  		= "Admin123"
	parameter_group_name 	= "default.postgres13"
	db_subnet_group_name    = aws_db_subnet_group.db_subnet_group.id
	availability_zone 	= "us-east-1a"
	skip_final_snapshot 	= true
	
}

#Create ELB

resource "aws_elb" "elb" {
 	name              	    = "terraform-elb"
	subnets			    = [aws_subnet.subnet1.id, aws_subnet.subnet2.id]
	instances                   = [aws_instance.EC2-1.id, aws_instance.EC2-2.id]
	security_groups		    = [aws_security_group.sg.id]


  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  tags = {
	  Name = "terraform-elb"
	  }
}

#Create SG

resource "aws_security_group" "sg" {
  name        = "allow_ssh_http"
  description = "Allow ssh http inbound traffic"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description      = "SSH from VPC"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "HTTP from VPC"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_ssh_http"
  }
}