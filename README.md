# S3P Signature (Dart)

This Dart package implements HMAC-SHA1 signature generation for authenticating requests to the **Smobilpay S3P API**

---

## ✨ Features

- ✅ Fully compliant with the [Smobilpay S3P API Authentication Spec](https://apidocs.smobilpay.com/s3papi/Authentication.1578338286.html)
- ✅ Supports `POST` and `GET` request types
- ✅ Automatically handles query string parsing for `GET` requests
- ✅ Strips trailing `?` from URLs to prevent canonical string errors
- ✅ Includes working test cases and example file

---

## 📦 Installation

Add this package to your Dart project:

```yaml
dependencies:
  s3p_signature:
    git:
      url: https://github.com/maviance/smobilpay-dart.git
