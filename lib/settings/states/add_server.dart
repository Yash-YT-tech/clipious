import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:clipious/settings/models/errors/server_already_exists.dart';
import 'package:clipious/utils/url_utils.dart';

import '../../globals.dart';
import '../models/db/server.dart';

part 'add_server.freezed.dart';

class AddServerCubit extends Cubit<AddServerState> {
  final TextEditingController urlController =
      TextEditingController(text: 'https://');
  final TextEditingController headerNameController = TextEditingController();
  final TextEditingController headerValueController = TextEditingController();

  AddServerCubit(super.initialState) {
    urlController.addListener(
      () {
        emit(state.copyWith(valid: validUrl));
      },
    );
  }

  @override
  Future<void> close() {
    urlController.dispose();
    headerNameController.dispose();
    headerValueController.dispose();
    return super.close();
  }

  Future<Server?> validateServer() async {
    emit(state.copyWith(loading: true));
    try {
      var serverUrl = normalizeInstanceUrl(urlController.value.text);

      final existingServer = db.getServer(serverUrl);

      if (existingServer != null) {
        throw ServerAlreadyExists();
      }

      await service.validateServer(serverUrl, state.headers);

      if (state.advancedTest) {
        Server server = Server(url: serverUrl, customHeaders: state.headers);
        // Parsing a real video validates the JSON schema used for playback.
        // Relative media/thumbnail URLs are supported and resolved by the app.
        await service.getVideo('dQw4w9WgXcQ', serverOverride: server);
      }

      return Server(url: serverUrl, customHeaders: state.headers);
    } finally {
      emit(state.copyWith(loading: false));
    }
  }

  setShowAdvanced(bool advanced) {
    emit(state.copyWith(showAdvanced: advanced));
  }

  addHeader(String key, String value) {
    final Map<String, String> headers = Map.from(state.headers);
    headers[key] = value;
    emit(state.copyWith(headers: headers));
  }

  removeHeader(String key) {
    final Map<String, String> headers = Map.from(state.headers);
    headers.remove(key);
    emit(state.copyWith(headers: headers));
  }

  bool get validUrl {
    final uri = Uri.tryParse(urlController.text.trim());
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  setAdvancedTest(bool advancedTest) {
    emit(state.copyWith(advancedTest: advancedTest));
  }
}

@freezed
sealed class AddServerState with _$AddServerState {
  const factory AddServerState(
      {@Default(false) bool loading,
      @Default(false) bool valid,
      @Default(false) bool showAdvanced,
      @Default(true) bool advancedTest,
      @Default({}) Map<String, String> headers}) = _AddServerState;
}
