# Private

This folder contains some information which we would like to keep private

To decrypt / encrypt you will need the secret key

Set the path to the secret key in env var

```
SECRET_KEY=/path/to/secret_key
```

## decrypt all files

```
( cd docs/private &&\
    for SRC in `ls *.encrypted`; do
        TARGET="$(echo "${FILE}" | cut -d. -f-2)"
        ! openssl enc -aes-256-cbc -pbkdf2 -iter 100000 -salt -d \
            -in "${SRC}" -out "${TARGET}" -pass "file:${SECRET_KEY}" \
                && echo failed to decryp $SRC && exit 1
    done )
```

## encrypt all files

```
( cd docs/private &&\
    for SRC in `ls conf*.yaml dat*.bin doc*.md`; do
        TARGET="${SRC}.encrypted"
        ! openssl enc -aes-256-cbc -pbkdf2 -iter 100000 -salt \
            -in "${SRC}" -out "${TARGET}" -pass "file:${SECRET_KEY}" \
                && echo failed to encrypt $SRC && exit 1
    done )
```