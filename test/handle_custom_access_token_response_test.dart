// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:oauth2_slackapi/oauth2_slackapi.dart' as oauth2;
import 'package:oauth2_slackapi/src/handle_access_token_response.dart';
import 'package:test/test.dart';

import 'utils.dart';

final Uri tokenEndpoint = Uri.parse("https://example.com/token");

final DateTime startTime = new DateTime.now();

//oauth2.Credentials handle(http.Response response) => handleAccessTokenResponse(
//    response, tokenEndpoint, startTime, ["scope"], ' ');
oauth2.Credentials handleCustom(http.Response response) =>
    handleCustomAccessTokenResponse(response, tokenEndpoint, startTime,
        ["scope"], ' ', true);
void main() {
  group('an error response', () {
    oauth2.Credentials handleErrorForSlackAPI(
            {String body: '{"error": "invalid_request"}',
            int statusCode: 400,
            Map<String, String> headers: const {
              "content-type": "application/json"
            }}) =>
        handleCustom(new http.Response(body, statusCode, headers: headers));

//    oauth2.Credentials handleError(
//        {String body: '{"error": "invalid_request"}',
//          int statusCode: 400,
//          Map<String, String> headers: const {
//            "content-type": "application/json"
//          }}) =>
//        handleCustom(new http.Response(body, statusCode, headers: headers), false);


    test('causes an AuthorizationException', () {
      expect(() => handleErrorForSlackAPI(), throwsAuthorizationException);
    });

    test('with a 401 code causes an AuthorizationException', () {
      expect(() => handleErrorForSlackAPI(statusCode: 401), throwsAuthorizationException);
    });

    test('with an unexpected code causes a FormatException', () {
      expect(() => handleErrorForSlackAPI(statusCode: 500), throwsFormatException);
    });

    test('with no content-type causes a FormatException', () {
      expect(() => handleErrorForSlackAPI(headers: {}), throwsFormatException);
    });

    test('with a non-JSON content-type causes a FormatException', () {
      expect(() => handleErrorForSlackAPI(headers: {'content-type': 'text/plain'}),
          throwsFormatException);
    });

    test(
        'with a JSON content-type and charset causes an '
        'AuthorizationException', () {
      expect(
          () => handleErrorForSlackAPI(
              headers: {'content-type': 'application/json; charset=UTF-8'}),
          throwsAuthorizationException);
    });

    test('with invalid JSON causes a FormatException', () {
      expect(() => handleErrorForSlackAPI(body: 'not json'), throwsFormatException);
    });

    test('with a non-string error causes a FormatException', () {
      expect(() => handleErrorForSlackAPI(body: '{"error": 12}'), throwsFormatException);
    });

    test('with a non-string error_description causes a FormatException', () {
      expect(
          () => handleErrorForSlackAPI(
              body: JSON.encode(
                  {"error": "invalid_request", "error_description": 12})),
          throwsFormatException);
    });

    test('with a non-string error_uri causes a FormatException', () {
      expect(
          () => handleErrorForSlackAPI(
              body: JSON.encode({"error": "invalid_request", "error_uri": 12})),
          throwsFormatException);
    });

    test('with a string error_description causes a AuthorizationException', () {
      expect(
          () => handleErrorForSlackAPI(
                  body: JSON.encode({
                "error": "invalid_request",
                "error_description": "description"
              })),
          throwsAuthorizationException);
    });

    test('with a string error_uri causes a AuthorizationException', () {
      expect(
          () => handleErrorForSlackAPI(
                  body: JSON.encode({
                "error": "invalid_request",
                "error_uri": "http://example.com/error"
              })),
          throwsAuthorizationException);
    });
  });

  group('a success response', () {
    oauth2.Credentials handleSuccess(
        {String contentType: "application/json",
        accessToken: 'access token',
        tokenType: 'bearer',
        expiresIn,
        refreshToken,
        scope}) {
      return handleCustom(new http.Response(
          JSON.encode({
            'access_token': accessToken,
//          The following commented out parameter will not include in slack's oauth.access response.
//            'token_type': tokenType,
//            'expires_in': expiresIn,
//            'refresh_token': refreshToken,
            'scope': scope
          }),
          200,
          headers: {'content-type': contentType}));
    }

    test('returns the correct credentials', () {
      var credentials = handleSuccess();
      expect(credentials.accessToken, equals('access token'));
      expect(credentials.tokenEndpoint.toString(),
          equals(tokenEndpoint.toString()));
    });

    test('with no content-type causes a FormatException', () {
      expect(() => handleSuccess(contentType: null), throwsFormatException);
    });

    test('with a non-JSON content-type causes a FormatException', () {
      expect(() => handleSuccess(contentType: 'text/plain'),
          throwsFormatException);
    });

    test(
        'with a JSON content-type and charset returns the correct '
        'credentials', () {
      var credentials =
          handleSuccess(contentType: 'application/json; charset=UTF-8');
      expect(credentials.accessToken, equals('access token'));
    });

    test('with a JavScript content-type returns the correct credentials', () {
      var credentials = handleSuccess(contentType: 'text/javascript');
      expect(credentials.accessToken, equals('access token'));
    });

    test('with a null access token throws a FormatException', () {
      expect(() => handleSuccess(accessToken: null), throwsFormatException);
    });

    test('with a non-string access token throws a FormatException', () {
      expect(() => handleSuccess(accessToken: 12), throwsFormatException);
    });

    test('with a non-string scope throws a FormatException', () {
      expect(() => handleSuccess(scope: 12), throwsFormatException);
    });

    test('with a scope sets the scopes', () {
      var credentials = handleSuccess(scope: "scope1 scope2");
      expect(credentials.scopes, equals(["scope1", "scope2"]));
    });

    test('with a custom scope delimiter sets the scopes', () {
      var response = new http.Response(
          JSON.encode({
            'access_token': 'access token',
//          The following commented out parameter will not include in slack's oauth.access response.
//            'token_type': 'bearer',
//            'expires_in': null,
//            'refresh_token': null,
            'scope': 'scope1,scope2'
          }),
          200,
          headers: {'content-type': 'application/json'});
      var credentials = handleCustomAccessTokenResponse(
          response, tokenEndpoint, startTime, ['scope'], ',', true);
      expect(credentials.scopes, equals(['scope1', 'scope2']));
    });
  });
}
