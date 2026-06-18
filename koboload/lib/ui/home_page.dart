import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/services/download_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _urlController = TextEditingController();
  final DownloadService _downloadService = DownloadService();

  String _diretorioDestino = "Carregando...";
  bool _estaProcessando = false; 
  bool _analiseConcluida = false;
  double _progressoAtual = 0.0;
  String _statusAtual = 'Aguardando link...';

  String _tipoMidia = 'video';
  String _qualidadeSelecionada = 'Maior Qualidade (Automático)';
  
  final List<String> _opcoesQualidade = ['Maior Qualidade (Automático)'];

  @override
  void initState() {
    super.initState();
    _carregarPastaSalva();
  }

  // --- CARREGA A PASTA DA MEMÓRIA ---
  Future<void> _carregarPastaSalva() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _diretorioDestino = prefs.getString('pasta_kobo') ?? "Nenhum diretório selecionado";
    });
  }

  // --- ESCOLHE E SALVA NOVA PASTA ---
  Future<void> _escolherPasta() async {
    String? caminho = await FilePicker.getDirectoryPath();
    if (caminho != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pasta_kobo', caminho);
      setState(() {
        _diretorioDestino = caminho;
      });
    }
  }

  // FASE 1: Extrair formatos reais via JSON
  Future<void> _analisarLink() async {
    if (_urlController.text.isEmpty) return;

    setState(() {
      _estaProcessando = true;
      _statusAtual = 'Inspecionando os veios de minério (Extraindo metadados)...';
      _progressoAtual = 0.5; 
    });

    List<String> resolucoesEncontradas = await _downloadService.extrairQualidades(_urlController.text);

    setState(() {
      _estaProcessando = false;
      _analiseConcluida = true;
      
      _opcoesQualidade.clear();
      _opcoesQualidade.addAll(resolucoesEncontradas);
      _qualidadeSelecionada = _opcoesQualidade.first; 
      
      _statusAtual = 'Análise concluída! Escolha a qualidade abaixo.';
      _progressoAtual = 0.0;
    });
  }

  // FASE 2: Fazer o download real
  void _iniciarMineracao() {
    if (_diretorioDestino == "Nenhum diretório selecionado" || _diretorioDestino == "Carregando...") {
      setState(() => _statusAtual = "Erro: Escolha uma pasta de destino primeiro!");
      return;
    }

    setState(() {
      _estaProcessando = true;
      _statusAtual = 'Preparando para extrair $_tipoMidia em $_qualidadeSelecionada...';
    });

    _downloadService.executarDownload(
      url: _urlController.text,
      caminhoDestino: _diretorioDestino,
      tipoMidia: _tipoMidia,
      qualidade: _qualidadeSelecionada,
      onProgress: (progresso, status) {
        setState(() {
          _progressoAtual = progresso;
          _statusAtual = status;
          if (progresso == 1.0 || status.contains("Erro") || status.contains("Falha")) {
            _estaProcessando = false;
          }
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('KoboLoad', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: ListView( 
              children: [
                Card(
                  color: Colors.black12,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    side: const BorderSide(color: Colors.deepOrange, width: 1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.folder_open, color: Colors.deepOrange, size: 32),
                    title: const Text('Pasta de Destino', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(_diretorioDestino),
                    trailing: FilledButton.tonal(
                      onPressed: _escolherPasta,
                      child: const Text('Alterar'),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                TextField(
                  controller: _urlController,
                  enabled: !_estaProcessando,
                  decoration: const InputDecoration(
                    labelText: 'Cole o link do vídeo aqui',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.link),
                  ),
                  onChanged: (value) {
                    if (_analiseConcluida) {
                      setState(() => _analiseConcluida = false);
                    }
                  },
                ),
                const SizedBox(height: 16),

                if (!_analiseConcluida)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(padding: const EdgeInsets.all(20)),
                    onPressed: _estaProcessando ? null : _analisarLink,
                    icon: _estaProcessando 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.search),
                    label: const Text('Analisar Link', style: TextStyle(fontSize: 18)),
                  ),

                if (_analiseConcluida) ...[
                  const Divider(height: 48, color: Colors.white24),
                  
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'video', icon: Icon(Icons.video_file), label: Text('Vídeo')),
                      ButtonSegment(value: 'audio', icon: Icon(Icons.audio_file), label: Text('Apenas Áudio')),
                    ],
                    selected: {_tipoMidia},
                    onSelectionChanged: (Set<String> selecao) {
                      setState(() => _tipoMidia = selecao.first);
                    },
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    initialValue: _qualidadeSelecionada,
                    decoration: const InputDecoration(
                      labelText: 'Qualidade/Formato',
                      border: OutlineInputBorder(),
                    ),
                    items: _opcoesQualidade.map((String qualidade) {
                      return DropdownMenuItem(value: qualidade, child: Text(qualidade));
                    }).toList(),
                    onChanged: (String? novaQualidade) {
                      if (novaQualidade != null) {
                        setState(() => _qualidadeSelecionada = novaQualidade);
                      }
                    },
                  ),
                  const SizedBox(height: 24),

                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.all(20),
                      backgroundColor: Colors.deepOrange, 
                    ),
                    onPressed: _estaProcessando ? null : _iniciarMineracao,
                    icon: _estaProcessando 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.download),
                    label: Text(_estaProcessando ? 'Extraindo...' : 'Iniciar Mineração', style: const TextStyle(fontSize: 18)),
                  ),
                ],

                const SizedBox(height: 40),
                
                LinearProgressIndicator(
                  value: _progressoAtual,
                  backgroundColor: Colors.black26,
                  color: Colors.deepOrange,
                ),
                const SizedBox(height: 16),
                Text(
                  _statusAtual,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _statusAtual.contains("Erro") ? Colors.red : Colors.grey,
                    fontWeight: FontWeight.bold
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}