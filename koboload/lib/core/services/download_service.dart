import 'dart:io';
import 'dart:convert';

class DownloadService {
  final String pastaYtdlp = r"C:\ytdlp";
  String get executavel => "$pastaYtdlp\\yt-dlp.exe";

  // ==========================================
  // FASE 1: EXTRAIR FORMATOS DISPONÍVEIS
  // ==========================================
  Future<List<String>> extrairQualidades(String url) async {
    print("KoboLoad: Inspecionando JSON de formatos...");
    
    try {
      var resultado = await Process.run(
        executavel,
        ['-J', '--no-warnings', url],
        workingDirectory: pastaYtdlp,
        stdoutEncoding: const SystemEncoding(), 
      );

      if (resultado.exitCode != 0) {
        print("Erro do yt-dlp: ${resultado.stderr}");
        return ['Erro ao buscar formatos'];
      }

      var jsonDados = jsonDecode(resultado.stdout);
      List formatos = jsonDados['formats'] ?? [];
      
      Set<String> resolucoesDisponiveis = {};
      bool possuiAudio = false;

      for (var f in formatos) {
        if (f['vcodec'] != 'none' && f['format_note'] != null) {
          String resolucao = f['format_note'].toString();
          if (resolucao.contains('p')) {
            resolucoesDisponiveis.add(resolucao);
          }
        }
        if (f['acodec'] != 'none') {
          possuiAudio = true;
        }
      }

      List<String> opcoesParaInterface = resolucoesDisponiveis.toList();
      opcoesParaInterface.insert(0, 'Maior Qualidade (Automático)');
      if (possuiAudio) {
        opcoesParaInterface.add('Apenas Áudio (MP3)');
      }

      return opcoesParaInterface.isNotEmpty 
          ? opcoesParaInterface 
          : ['Maior Qualidade (Automático)'];

    } catch (e) {
      print("Erro ao tentar fazer parse do JSON: $e");
      return ['Maior Qualidade (Automático)'];
    }
  }

  // ==========================================
  // FASE 2: FAZER O DOWNLOAD REAL
  // ==========================================
  Future<void> executarDownload({
    required String url,
    required String caminhoDestino,
    required String tipoMidia,
    required String qualidade,
    Function(double progresso, String status)? onProgress,
  }) async {
    if (url.isEmpty) return;
    if (onProgress != null) onProgress(0.0, "Preparando equipamentos...");

    List<String> argumentos = [];

    // Regra 1: Áudio ou Vídeo
    if (tipoMidia == 'audio' || qualidade.contains('Áudio')) {
      argumentos.addAll(["-f", "bestaudio", "--extract-audio", "--audio-format", "mp3"]);
    } else {
      String formatoVideo = "bv*+ba/best"; 
      if (qualidade != 'Maior Qualidade (Automático)' && qualidade.contains('p')) {
        String altura = qualidade.replaceAll(RegExp(r'[^0-9]'), '');
        if (altura.isNotEmpty) {
          formatoVideo = "bestvideo[height<=$altura]+bestaudio/best";
        }
      }
      argumentos.addAll(["-f", formatoVideo]);
    }

    // Regra 2: Destino Final
    argumentos.addAll([
      "--no-warnings",
      "-o", "$caminhoDestino\\%(title)s.%(ext)s", // Salva na pasta escolhida com o título real
      url
    ]);

    try {
      var process = await Process.start(
        executavel,
        argumentos,
        workingDirectory: pastaYtdlp,
      );

      RegExp regexProgresso = RegExp(r'\[download\]\s+([0-9\.]+)\%');

      process.stdout.transform(const Utf8Decoder(allowMalformed: true)).listen((data) {
        String linha = data.trim();
        print(linha); 
        
        var match = regexProgresso.firstMatch(linha);
        if (match != null && onProgress != null) {
          double percentual = double.parse(match.group(1)!) / 100;
          onProgress(percentual, "Enviando minério para a pasta (Baixando)...");
        } else if (linha.contains("Merging formats")) {
          if (onProgress != null) onProgress(0.99, "Fundindo Áudio e Vídeo...");
        } else if (linha.contains("Extracting audio")) {
          if (onProgress != null) onProgress(0.99, "Convertendo para MP3...");
        }
      });

      process.stderr.transform(const Utf8Decoder(allowMalformed: true)).listen((data) {
        print("ALERTA: ${data.trim()}");
      });

      var exitCode = await process.exitCode;
      if (exitCode == 0) {
        if (onProgress != null) onProgress(1.0, "Extração concluída! Arquivo na pasta.");
      } else {
        if (onProgress != null) onProgress(0.0, "Falha na extração. Código: $exitCode");
      }

    } catch (e) {
      if (onProgress != null) onProgress(0.0, "Erro fatal no yt-dlp.");
    }
  }
}