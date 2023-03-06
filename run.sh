dfx start --clean --background
dfx identity new --disable-encryption test_$1
dfx identity use test_$1
dfx deploy --with-cycles 25000000000000