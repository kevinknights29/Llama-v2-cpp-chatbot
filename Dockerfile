# Sources:
# https://github.com/orgs/python-poetry/discussions/1879#discussioncomment-216865
# https://bmaingret.github.io/blog/2021-11-15-Docker-and-Poetry
# `python-base` sets up environment variables
FROM python:3.11.4-slim-bullseye as python-base

ARG APP_NAME=app
ARG APP_PATH=/opt/$APP_NAME
ARG PACKAGE_NAME=app
ARG PYTHON_VERSION=3.11.4
ARG POETRY_VERSION=1.5.1
ARG MODEL_FILENAME=llama-2-7b.ggmlv3.q4_0.bin
ARG MODEL_URL=https://huggingface.co/TheBloke/Llama-2-7B-GGML/resolve/main/llama-2-7b.ggmlv3.q4_0.bin

ENV PYTHONUNBUFFERED=1 \
    PYTHONFAULTHANDLER=1 \
    # prevents python creating .pyc files
    PYTHONDONTWRITEBYTECODE=1 \
    \
    # pip
    PIP_NO_CACHE_DIR=off \
    PIP_DISABLE_PIP_VERSION_CHECK=on \
    PIP_DEFAULT_TIMEOUT=100 \
    \
    # poetry
    # https://python-poetry.org/docs/configuration/#using-environment-variables
    POETRY_VERSION=${POETRY_VERSION} \
    # make poetry install to this location
    POETRY_HOME="/opt/poetry" \
    # make poetry create the virtual environment in the project's root
    # it gets named `.venv`
    POETRY_VIRTUALENVS_IN_PROJECT=true \
    # do not ask any interactive question
    POETRY_NO_INTERACTION=1 \
    # make poetry always create a new virtual environment
    POETRY_VIRTUALENVS_IN_PROJECT=1 \
    POETRY_VIRTUALENVS_CREATE=1 \
    # set cache path
    POETRY_CACHE_DIR=/tmp/poetry_cache

# `builder-base` stage is used to build deps + create our virtual environment
FROM python-base as builder-base

RUN apt-get update \
    && apt-get install --no-install-recommends -y \
        # deps for installing poetry
        curl \
        # deps for building python deps
        build-essential \
        python3-dev \
        gcc

# download model
RUN mkdir -p /opt/models
RUN curl -L $MODEL_URL -o /opt/models/${MODEL_FILENAME}

# set llama.cpp environment variables for python
ENV CMAKE_ARGS="-DLLAMA_CUBLAS=on" \
    FORCE_CMAKE=1

# prepend poetry and venv to path
ENV PATH="$POETRY_HOME/bin:$VENV_PATH/bin:$PATH"

# install poetry - respects $POETRY_VERSION & $POETRY_HOME
RUN curl -sSL https://install.python-poetry.org | python3 -

# copy project requirement files here to ensure they will be cached.
WORKDIR $APP_PATH
COPY ./$APP_NAME/poetry.lock ./$APP_NAME/pyproject.toml ./
ADD ./$APP_NAME ./

# install runtime deps - uses $POETRY_VIRTUALENVS_IN_PROJECT internally
RUN poetry install
# you can exclude the development dependencies by adding --no-dev to the previous command.

# `development` image is used during development / testing
FROM builder-base as development

ENV HOST=0.0.0.0
ENV LISTEN_PORT 8000

WORKDIR $APP_PATH

# copy in our built poetry + venv
COPY --from=builder-base $POETRY_HOME $POETRY_HOME
COPY --from=builder-base $APP_PATH $APP_PATH

# quicker install as runtime deps are already installed
RUN poetry install

# install llama-cpp package for python
RUN poetry run pip install llama-cpp-python

EXPOSE 8000
ENTRYPOINT ["poetry", "run"]
# add your script at the end
CMD ["chainlit", "run", "chatbot.py"]
