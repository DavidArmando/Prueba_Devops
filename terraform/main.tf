# 1. Crear el Bucket S3 para alojar los estáticos
resource "aws_s3_bucket" "angular_app_bucket" {
  bucket = "mi-app-angular-bucket-unico-12345" # Cambia por un nombre único
}

# Bloquear todo el acceso público al bucket por seguridad
resource "aws_s3_bucket_public_access_block" "public_access_block" {
  bucket                  = aws_s3_bucket.angular_app_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 2. Configurar Origin Access Control (OAC) para CloudFront
resource "aws_cloudfront_origin_access_control" "default" {
  name                              = "angular-app-oac"
  description                       = "OAC para acceder al bucket S3 de la app Angular"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# 3. Crear la Distribución de CloudFront
resource "aws_cloudfront_distribution" "angular_distribution" {
  origin {
    domain_name              = aws_s3_bucket.angular_app_bucket.bucket_regional_domain_name
    origin_id                = "S3-${aws_s3_bucket.angular_app_bucket.id}"
    origin_access_control_id = aws_cloudfront_origin_access_control.default.id
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html" # Archivo principal de Angular

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.angular_app_bucket.id}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https" # Obliga a usar HTTPS
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  # Configuración para que las rutas de Angular (SPA) funcionen devolviendo el index.html
  custom_error_response {
    error_caching_min_ttl = 300
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
  }

  custom_error_response {
    error_caching_min_ttl = 300
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true # Puedes añadir tu certificado SSL personalizado de ACM aquí
  }
}

# 4. Política del Bucket para permitir a CloudFront leer los archivos
data "aws_iam_policy_document" "s3_policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.angular_app_bucket.arn}/*"]
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.angular_distribution.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "s3_bucket_policy" {
  bucket = aws_s3_bucket.angular_app_bucket.id
  policy = data.aws_iam_policy_document.s3_policy.json
}

# Outputs para obtener los IDs al finalizar
output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.angular_distribution.domain_name
}

output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.angular_distribution.id
}