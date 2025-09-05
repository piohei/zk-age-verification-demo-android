use chrono::Utc;
use flutter_rust_bridge::for_generated::anyhow;
use x509_parser::prelude::{FromDer, X509Certificate};

struct InputFile {
    min_age_required: u8,
    max_age_required: u8,
    current_date: String,

    dg1: [u8; 95],
    dg1_hash_offset_in_sod: u32,

    passport_sod: [u8; 700],
    passport_sod_size: u32,

    sod_cert: [u8; 200],
    sod_cert_size: u32,
    sod_cert_signature: [u8; 256],

    dsc_cert: [u8; 700],
    dsc_cert_len: u32,
    dsc_cert_signature: [u8; 256],

    dsc_pubkey_offset_in_dsc_cert: u32,
    dsc_pubkey: [u8; 256],
    dsc_barrett_mu: [u8; 257],
    dsc_rsa_exponent: u32,

    csc_pubkey: [u8; 256],
    csc_barrett_mu: [u8; 257],
    csc_rsa_exponent: u32,
}

// impl InputFile {
//     pub fn new(csca_cert: &[u8], dsc_cert: &[u8], sod_cert: &[u8], sod: &[u8], dg1: &[u8]) -> anyhow::Result<InputFile> {
//         let (_, csca_cert) = X509Certificate::from_der(csca_cert)?;
//         let (_, dsc_cert) = X509Certificate::from_der(dsc_cert)?;
//
//         InputFile {
//             min_age_required: 18,
//             max_age_required: 150,
//             current_date: Utc::now().format("%Y%m%d").to_string(),
//             dg1: dg1.into(),
//             dg1_hash_offset_in_sod: 0,
//             passport_sod: vec![],
//             passport_sod_size: 0,
//             sod_cert: vec![],
//             sod_cert_size: 0,
//             sod_cert_signature: vec![],
//             dsc_cert: vec![],
//             dsc_cert_len: 0,
//             dsc_cert_signature: vec![],
//             dsc_pubkey_offset_in_dsc_cert: 0,
//             dsc_pubkey: vec![],
//             dsc_barrett_mu: vec![],
//             dsc_rsa_exponent: 0,
//             csc_pubkey: csca_cert.public_key().raw.into(),
//             csc_barrett_mu: vec![],
//             csc_rsa_exponent: 0,
//         }
//     }
// }