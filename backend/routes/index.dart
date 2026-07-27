// Copyright 2026 eabarriosTGC
// SPDX-License-Identifier: Apache-2.0

import 'package:dart_frog/dart_frog.dart';

Response onRequest(RequestContext context) {
  return Response.json(body: {
    'service': 'Moteros API',
    'version': '1.0.0',
    'status': 'running',
  });
}
