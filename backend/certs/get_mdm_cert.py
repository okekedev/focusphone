#!/usr/bin/env python3
"""
MDM Push Certificate Request Script
Uses mdmcert.download to sign our CSR for Apple's MDM Push Certificate
"""

import os
import json
import base64
import subprocess
import sys
from pathlib import Path

CERTS_DIR = Path(__file__).parent
MDMCERT_API_KEY = "f847aea2ba06b41264d587b229e2712c89b1490a1208b7ff1aafab5bb40d47bc"

def run_cmd(cmd):
    """Run a shell command and return output"""
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"Error: {result.stderr}")
        raise Exception(f"Command failed: {cmd}")
    return result.stdout.strip()

def generate_certs():
    """Generate all required certificates and keys"""
    print("\n=== Step 1: Generating Keys and CSR ===\n")

    # MDM Push private key
    push_key_path = CERTS_DIR / "mdm_push_key.pem"
    push_csr_path = CERTS_DIR / "mdm_push.csr"

    if not push_key_path.exists():
        print("Generating MDM Push private key...")
        run_cmd(f'openssl genrsa -out "{push_key_path}" 2048')
        print(f"  Created: {push_key_path}")
    else:
        print(f"  Using existing: {push_key_path}")

    if not push_csr_path.exists():
        print("Generating MDM Push CSR...")
        run_cmd(f'openssl req -new -key "{push_key_path}" -out "{push_csr_path}" -subj "/C=US/ST=California/L=San Francisco/O=FocusPhone/OU=MDM/CN=FocusPhone MDM"')
        print(f"  Created: {push_csr_path}")
    else:
        print(f"  Using existing: {push_csr_path}")

    # Encryption key pair (for encrypting the response from mdmcert)
    enc_key_path = CERTS_DIR / "encrypt_key.pem"
    enc_cert_path = CERTS_DIR / "encrypt_cert.pem"

    if not enc_key_path.exists():
        print("Generating encryption key pair...")
        run_cmd(f'openssl genrsa -out "{enc_key_path}" 2048')
        run_cmd(f'openssl req -new -x509 -key "{enc_key_path}" -out "{enc_cert_path}" -days 365 -subj "/CN=MDM Encrypt"')
        print(f"  Created: {enc_key_path}")
        print(f"  Created: {enc_cert_path}")
    else:
        print(f"  Using existing encryption key pair")

    return push_csr_path, enc_cert_path

def submit_request(email):
    """Submit CSR to mdmcert.download"""
    print("\n=== Step 2: Submitting to mdmcert.download ===\n")

    push_csr_path = CERTS_DIR / "mdm_push.csr"
    enc_cert_path = CERTS_DIR / "encrypt_cert.pem"

    # Read CSR (PEM format)
    with open(push_csr_path, 'r') as f:
        push_csr = f.read()

    # Read encryption cert (PEM format)
    with open(enc_cert_path, 'r') as f:
        encrypt_cert = f.read()

    # Base64 encode both
    csr_b64 = base64.b64encode(push_csr.encode()).decode()
    cert_b64 = base64.b64encode(encrypt_cert.encode()).decode()

    request_data = {
        "email": email,
        "csr": csr_b64,
        "encrypt": cert_b64,
        "key": MDMCERT_API_KEY
    }

    # Save request for debugging
    request_path = CERTS_DIR / "mdmcert_request.json"
    with open(request_path, 'w') as f:
        json.dump(request_data, f, indent=2)
    print(f"  Request saved to: {request_path}")

    # Submit to API
    import urllib.request
    import urllib.error

    url = "https://mdmcert.download/api/v1/signrequest"
    headers = {
        "Content-Type": "application/json",
        "User-Agent": "micromdm/certhelper"
    }

    req = urllib.request.Request(
        url,
        data=json.dumps(request_data).encode('utf-8'),
        headers=headers,
        method='POST'
    )

    try:
        with urllib.request.urlopen(req, timeout=30) as response:
            result = json.loads(response.read().decode())
            print(f"  Response: {result}")

            if result.get("result") == "success":
                print("\n✅ Request submitted successfully!")
                print("\n=== NEXT STEPS ===")
                print("1. Check your email for the signed request from mdmcert.download")
                print("2. Save the attachment to ~/Downloads/")
                print("3. Run: python3 get_mdm_cert.py --decrypt")
            else:
                print(f"  Error: {result}")

    except urllib.error.HTTPError as e:
        error_body = e.read().decode()
        print(f"  HTTP Error {e.code}: {error_body}")
    except Exception as e:
        print(f"  Error: {e}")

def decrypt_response():
    """Decrypt the signed CSR received from mdmcert.download"""
    print("\n=== Decrypting Signed Request ===\n")

    # Find the downloaded file
    downloads = Path.home() / "Downloads"
    signed_files = list(downloads.glob("mdm_signed_request.*.p7"))

    if not signed_files:
        print("Error: No signed request file found in ~/Downloads/")
        print("Looking for: mdm_signed_request.*.plist.b64.p7")
        return

    signed_path = signed_files[0]
    print(f"Found signed request: {signed_path}")

    enc_key_path = CERTS_DIR / "encrypt_key.pem"
    enc_cert_path = CERTS_DIR / "encrypt_cert.pem"

    # Step 1: Read hex-encoded file
    print("\n1. Reading hex-encoded file...")
    with open(signed_path, 'r') as f:
        hex_content = f.read().strip()

    # Step 2: Convert hex to binary
    print("2. Converting hex to binary...")
    binary_content = bytes.fromhex(hex_content)
    binary_path = CERTS_DIR / "mdm_signed_binary.p7"
    with open(binary_path, 'wb') as f:
        f.write(binary_content)

    # Step 3: Decrypt PKCS7 using openssl
    print("3. Decrypting PKCS7 envelope...")
    output_path = CERTS_DIR / "push_certificate_request.b64"

    cmd = f'openssl smime -decrypt -inform DER -in "{binary_path}" -inkey "{enc_key_path}" -recip "{enc_cert_path}" -out "{output_path}"'
    try:
        run_cmd(cmd)
    except:
        # Try without -recip
        cmd = f'openssl smime -decrypt -inform DER -in "{binary_path}" -inkey "{enc_key_path}" -out "{output_path}"'
        run_cmd(cmd)

    print(f"  Decrypted to: {output_path}")

    # Step 4: The output is base64-encoded plist - this is what Apple wants
    print("\n4. Verifying output...")
    with open(output_path, 'r') as f:
        content = f.read()

    # Check if it's base64 by trying to decode it
    try:
        decoded = base64.b64decode(content)
        if b'<?xml' in decoded and b'plist' in decoded:
            print("  ✅ Valid base64-encoded plist")

            # Also save the decoded version for inspection
            decoded_path = CERTS_DIR / "push_certificate_request.plist"
            with open(decoded_path, 'wb') as f:
                f.write(decoded)
            print(f"  Decoded plist saved to: {decoded_path}")
    except:
        print("  ⚠️ Content may not be base64 encoded")

    print("\n" + "="*50)
    print("✅ Decryption complete!")
    print("="*50)
    print("\nUpload ONE of these files to https://identity.apple.com/pushcert:")
    print(f"\n  Option 1 (base64): {output_path}")
    print(f"  Option 2 (plist):  {CERTS_DIR / 'push_certificate_request.plist'}")
    print("\nClick 'Create a Certificate' and upload the file.")

def main():
    if len(sys.argv) > 1 and sys.argv[1] == "--decrypt":
        decrypt_response()
    else:
        email = input("Enter the email you registered with mdmcert.download: ").strip()
        generate_certs()
        submit_request(email)

if __name__ == "__main__":
    main()
