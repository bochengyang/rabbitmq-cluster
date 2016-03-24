NAME = goatman/rabbitmq
VERSION = 3.6.1

.PHONY: all check_update build

all: build

build:
	docker build -t $(NAME):$(VERSION) --rm .
