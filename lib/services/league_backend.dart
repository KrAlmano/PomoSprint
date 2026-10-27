import 'service_errors.dart';

typedef LeagueRpc = Future<Object?> Function(String name);

/// Eski RPC yalnız yeni sözleşme sunucuda yoksa denenir. Ağ, izin veya
/// sunucu hatası eski ödül kurallarını kullanarak başarıya çevrilmez.
Future<Object?> fetchLeagueRankingResponse(LeagueRpc rpc) async {
  try {
    return await rpc('get_my_league_ranking_v2');
  } catch (error) {
    if (!isMissingRpcError(error)) rethrow;
    return rpc('get_my_league_ranking');
  }
}

Future<Object?> fetchLeagueRulesResponse(LeagueRpc rpc) async {
  try {
    return await rpc('get_league_config');
  } catch (error) {
    if (!isMissingRpcError(error)) rethrow;
    return rpc('get_app_config');
  }
}
