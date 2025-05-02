# S3P Signature (Dart)

This Dart package implements the HMAC-SHA1 signature generation required for authenticating requests to the **Smobilpay S3P API**.

It supports both `GET` and `POST` requests, using a percent-encoded anonical string with base64-encoded HMAC-SHA1 hashing.

---

## ✨ Features

- Compliant with [S3P API Authentication Spec](https://apidocs.smobilpay.com/s3papi/Authentication.1578338286.html)
- Named constructors for `GET` and `POST` signatures
- Uses Dart's standard `crypto` and `convert` packages
- Tested and validated against official Java implementation

---

## 📦 Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  s3p_signature:
    git:
      url: https://github.com/your-username/s3p_signature.git
