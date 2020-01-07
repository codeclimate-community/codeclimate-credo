.PHONY: image

IMAGE_NAME ?= codeclimate/codeclimate-credo 

image:
	 docker build --rm -t $(IMAGE_NAME) .

