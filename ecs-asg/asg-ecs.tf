data "terraform_remote_state" "common" {
  backend = "s3"
  config {
    bucket = "aho-sf-vwis-tfstate"
    key    = "common/terraform.tfstate"
    region = "eu-west-1"
  }
}

data "terraform_remote_state" "static_iam" {
  backend = "s3"
  config {
    bucket = "aho-sf-vwis-tfstate"
    key    = "static/iam/terraform.tfstate"
    region = "eu-west-1"
  }
}



resource "aws_launch_configuration" "jks_agent_on_demand" {
  instance_type               = "${var.instance_type}"
  image_id                    = "${lookup(var.ecs_image_id, var.aws_region)}"
  iam_instance_profile        = "${data.terraform_remote_state.static_iam.ecs_instance_profile}"
  user_data                   = "${data.template_file.autoscaling_user_data.rendered}"
  key_name                    = "${var.ec2_key_name}"
  security_groups             = ["${data.terraform_remote_state.common.sg_jks_agent_id}"]
  associate_public_ip_address = true

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "jks_agent_on_demand" {
  name                      = "${var.name_prefix}_jks_agent_on_demand"
  max_size                  = 50
  min_size                  = 0
  desired_capacity          = "${var.desired_capacity_on_demand}"
  health_check_grace_period = 300
  health_check_type         = "EC2"
  force_delete              = true
  launch_configuration      = "${aws_launch_configuration.jks_agent_on_demand.name}"
  vpc_zone_identifier       = ["${data.terraform_remote_state.common.subnet_ids}"]

  tag {
    key                 = "Name"
    value               = "${var.name_prefix}-jks_agent-on-demand"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

data "template_file" "autoscaling_user_data" {
  template = "${file("autoscaling_user_data.tpl")}"

  vars {
    ecs_cluster = "${aws_ecs_cluster.jks_agent_cluster.name}"
  }
}
