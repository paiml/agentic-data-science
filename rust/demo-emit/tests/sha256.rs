use demo_emit::sha256::sha256_hex;

#[test]
fn nist_empty() {
    assert_eq!(
        sha256_hex(b""),
        "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
    );
}

#[test]
fn nist_abc() {
    assert_eq!(
        sha256_hex(b"abc"),
        "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
    );
}

#[test]
fn nist_two_block_message() {
    assert_eq!(
        sha256_hex(b"abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"),
        "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1"
    );
}

#[test]
fn nist_one_million_a() {
    let m = vec![b'a'; 1_000_000];
    assert_eq!(
        sha256_hex(&m),
        "cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0"
    );
}

#[test]
fn padding_boundaries_differ_and_are_stable() {
    // 55, 56 and 64 bytes straddle the one-block / two-block padding boundary.
    let a = sha256_hex(&[b'x'; 55]);
    let b = sha256_hex(&[b'x'; 56]);
    let c = sha256_hex(&[b'x'; 64]);
    assert!(a != b && b != c && a != c);
    assert_eq!(a.len(), 64);
    assert_eq!(a, sha256_hex(&[b'x'; 55]));
}
