include base.mk

# recursive variables
CASC_FILE = casc.yaml
CHILD_CASC_FILE = child-casc.yaml
TEMP_CASC_FILE = temp-casc.yaml

# targets
CONFIGS = configs

define ANSIBLE_INVENTORY =
cat << _EOF_
all:
  hosts:
    localhost:
      email_secret:
_EOF_
endef
export ANSIBLE_INVENTORY

# include other generic makefiles
include docker.mk
export CONTAINER_NAME = jenkins-torkel
export CONTAINER_NETWORK = jbc1
export CONTAINER_VOLUME = jenkins_home:/var/jenkins_home
DOCKER_REPO = cavcrosby/jenkins-torkel
DOCKER_VCS_LABEL = tech.cavcrosby.jenkins.base.vcs-repo=https://github.com/cavcrosby/jenkins-docker-torkel

include python.mk
# overrides defaults set by included makefiles
VIRTUALENV_PYTHON_VERSION = 3.9.5

include ansible.mk
ANSISRC = $(shell find . \
	\( \
		\( -type f \) \
		-or \( -name '*.yml' \) \
	\) \
	-and ! \( -name '.python-version' \) \
	-and ! \( -path '*.git*' \) \
)

# executables
JCASCUTIL = jcascutil.py

# simply expanded variables
executables := \
	${JCASCUTIL}\
	${python_executables}\
	${docker_executables}

_check_executables := $(foreach exec,${executables},$(if $(shell command -v ${exec}),pass,$(error "No ${exec} in PATH")))

.PHONY: ${HELP}
${HELP}:
	# inspired by the makefiles of the Linux kernel and Mercurial
>	@echo 'Available make targets:'
>	@echo '  ${SETUP}        - installs the distro-independent dependencies for this'
>	@echo '                 project and runs the needed jcascutil setup'
>	@echo '  ${CONFIGS}      - creates/pulls the needed material to perform a docker build'
>	@echo '  ${IMAGE}        - creates the base docker image that host Jenkins'
>	@echo '  ${DEPLOY}       - creates a container from the project image'
>	@echo '  ${DISMANTLE}    - removes a deployed container and the supporting'
>	@echo '                 environment setup'
>	@echo '  ${CLEAN}        - removes files generated from the configs target'

.PHONY: ${SETUP}
${SETUP}: ${DOCKER_ANSIBLE_INVENTORY} ${PYENV_POETRY_SETUP}
>	${JCASCUTIL} setup

.PHONY: ${CONFIGS}
${CONFIGS}:
>	${JCASCUTIL} addjobs --transform-rffw --merge-casc "${CHILD_CASC_FILE}" > "${TEMP_CASC_FILE}"
>	${JCASCUTIL} addagent-placeholder --numagents 1 --casc-path "${TEMP_CASC_FILE}" > "${CASC_FILE}"
>	rm --force "${TEMP_CASC_FILE}"

.PHONY: ${IMAGE}
${IMAGE}: ${DOCKER_IMAGE}

.PHONY: ${DEPLOY}
${DEPLOY}: ${DOCKER_TEST_DEPLOY}

.PHONY: ${DISMANTLE}
${DISMANTLE}: ${DOCKER_TEST_DEPLOY_DISMANTLE}

.PHONY: ${CLEAN}
${CLEAN}: ${DOCKER_IMAGE_CLEAN}
>	rm --force "${CASC_FILE}"
>	${JCASCUTIL} setup --clean
