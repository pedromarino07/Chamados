import 'package:supabase_flutter/supabase_flutter.dart'; 
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Garante a inicialização do Flutter

  await Supabase.initialize(
    url: 'https://iafuxadyfuizngtzkvdf.supabase.co', 
    anonKey: 'sb_publishable_iNfsTbEnj-wR71BGu-_Suw_ny7Exroh',
  );

  runApp(const SistemaChamados());
}

class SistemaChamados extends StatelessWidget {
  const SistemaChamados({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('pt', 'BR'),
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFF15A22),
          primary: const Color(0xFFF15A22),
          secondary: const Color(0xFFFFE6CB),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF15A22),
          foregroundColor: Colors.white,
        ),
      ),
      initialRoute: '/',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(builder: (_) => const TelaLogin());
          case '/usuario':
            final usuario = settings.arguments as Usuario?;
            return MaterialPageRoute(builder: (_) => DashboardUsuario(usuario: usuario));
          case '/suporte':
            final usuario = settings.arguments as Usuario?;
            return MaterialPageRoute(builder: (_) => DashboardSuporte(usuario: usuario));
          case '/admin':
            return MaterialPageRoute(builder: (_) => const DashboardAdmin());
          default:
            return MaterialPageRoute(builder: (_) => const TelaLogin());
        }
      },
    );
  }
}

// --- MODELO DE DADOS ---
enum NivelUrgencia { baixa, normal, alta }

class Chamado {
  final String id;
  final String setor;
  final String solicitante;
  final String problema;
  final String ramal;
  final DateTime dataHora;
  DateTime? dataFinalizacao;
  final NivelUrgencia urgencia;
  String status; // 'A iniciar', 'Em andamento', 'Aguardando Confirmação', 'Finalizado'
  String? tecnico;
  String? classificacao;
  List<String> observacoes;
  List<String> justificativas;

  Chamado({
    required this.id,
    required this.setor,
    required this.solicitante,
    required this.problema,
    required this.ramal,
    required this.dataHora,
    this.dataFinalizacao,
    this.urgencia = NivelUrgencia.normal,
    this.status = 'A iniciar',
    this.tecnico,
    this.classificacao,
    this.observacoes = const [],
    this.justificativas = const [],
  });
}

// Lista global simulando um banco de dados para o teste
List<Chamado> bancoDeDadosGlobal = [];
List<String> setoresGlobal = ['Geral', 'TI', 'RH'];
List<String> listaClassificacoes = ['Impressora', 'Internet', 'Hardware', 'Software'];

// --- FUNÇÕES AUXILIARES (ID e ORDENAÇÃO) ---
String _gerarNovoId() {
  int maxId = 0;
  for (var c in bancoDeDadosGlobal) {
    int? id = int.tryParse(c.id);
    if (id != null && id > maxId) maxId = id;
  }
  return (maxId + 1).toString().padLeft(5, '0');
}

void _ordenarPorPrioridade() {
  bancoDeDadosGlobal.sort((a, b) {
    int cmp = b.urgencia.index.compareTo(a.urgencia.index); // Alta (2) > Normal (1) > Baixa (0)
    return cmp != 0 ? cmp : a.id.compareTo(b.id); // Desempate por ID (FIFO)
  });
}

Color _getCorPrazo(DateTime dataHora) {
  final horas = DateTime.now().difference(dataHora).inHours;
  if (horas <= 24) {
    return Colors.green;
  } else if (horas <= 48) {
    return Colors.yellow;
  } else {
    return Colors.red;
  }
}

// --- MODELO DE USUÁRIO E MOCK ---
enum TipoPerfil { usuario, suporte, admin }

enum SetorTecnico { sistemas, hardwares }

class Usuario {
  final String login;
  String senha;
  final String nome;
  final TipoPerfil perfil;
  bool primeiroAcesso;
  final DateTime dataCadastro;
  bool ativo;
  SetorTecnico? setorTecnico;

  Usuario({
    required this.login,
    required this.senha,
    required this.nome,
    required this.perfil,
    this.primeiroAcesso = false,
    DateTime? dataCadastro,
    this.ativo = true,
    this.setorTecnico,
  }) : dataCadastro = dataCadastro ?? DateTime.now();
}

final List<Usuario> usuariosMock = [
  Usuario(login: 'user', senha: '123', nome: 'João Silva', perfil: TipoPerfil.usuario),
  Usuario(login: 'tec', senha: '123', nome: 'Técnico Pedro', perfil: TipoPerfil.suporte),
  Usuario(login: 'tec', senha: '123', nome: 'Técnico Pedro', perfil: TipoPerfil.suporte, setorTecnico: SetorTecnico.hardwares),
  Usuario(login: 'ana', senha: '123', nome: 'Ana (Sistemas)', perfil: TipoPerfil.suporte, setorTecnico: SetorTecnico.sistemas),
  Usuario(login: 'admin', senha: '123', nome: 'Admin', perfil: TipoPerfil.admin),
];

// --- TELA DE LOGIN ---
class TelaLogin extends StatefulWidget {
  const TelaLogin({super.key});

  @override
  State<TelaLogin> createState() => _TelaLoginState();
}

class _TelaLoginState extends State<TelaLogin> {
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  final _userFocusNode = FocusNode();
  final _passFocusNode = FocusNode();

  @override
  void dispose() {
    _userController.dispose();
    _passController.dispose();
    _userFocusNode.dispose();
    _passFocusNode.dispose();
    super.dispose();
  }

  void _login() {
    final user = _userController.text.trim();
    final pass = _passController.text.trim();

    try {
      final usuarioLogado = usuariosMock.firstWhere((u) => u.login == user && u.senha == pass);

      if (usuarioLogado.primeiroAcesso) {
        _alterarSenhaPrimeiroAcesso(usuarioLogado);
      } else {
        _navegarParaDashboard(usuarioLogado);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Credenciais inválidas!")));
    }
  }

  void _navegarParaDashboard(Usuario usuario) {
    if (usuario.perfil == TipoPerfil.usuario) {
      Navigator.pushReplacementNamed(context, '/usuario', arguments: usuario);
    } else if (usuario.perfil == TipoPerfil.suporte) {
      Navigator.pushReplacementNamed(context, '/suporte', arguments: usuario);
    } else if (usuario.perfil == TipoPerfil.admin) {
      Navigator.pushReplacementNamed(context, '/admin');
    }
  }

  void _alterarSenhaPrimeiroAcesso(Usuario usuario) {
    final novaSenhaCtrl = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("Primeiro Acesso"),
        content: TextField(controller: novaSenhaCtrl, decoration: const InputDecoration(labelText: "Defina uma nova senha"), obscureText: true),
        actions: [
          ElevatedButton(
            onPressed: () {
              usuario.senha = novaSenhaCtrl.text;
              usuario.primeiroAcesso = false;
              Navigator.pop(ctx);
              _navegarParaDashboard(usuario);
            },
            child: const Text("Salvar e Entrar"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: SizedBox(
            width: 350,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Espaço para Logo
                Image.asset('assets/images/helpdesk.png', height: 200),
                const SizedBox(height: 0),
                const SizedBox(height: 10),
                TextField(
                  controller: _userController,
                  focusNode: _userFocusNode,
                  decoration: const InputDecoration(labelText: 'Usuário', border: OutlineInputBorder()),
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) {
                    FocusScope.of(context).requestFocus(_passFocusNode);
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passController,
                  focusNode: _passFocusNode,
                  decoration: const InputDecoration(labelText: 'Senha', border: OutlineInputBorder()),
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _login(),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                  onPressed: _login,
                  child: const Text("ENTRAR"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- VISÃO DO USUÁRIO (SOLICITAR) ---
class DashboardUsuario extends StatefulWidget {
  final Usuario? usuario;
  const DashboardUsuario({super.key, this.usuario});

  @override
  State<DashboardUsuario> createState() => _DashboardUsuarioState();
}

class _DashboardUsuarioState extends State<DashboardUsuario> with SingleTickerProviderStateMixin {
  String _setorSelecionado = setoresGlobal.first;
  final _nome = TextEditingController();
  final _problema = TextEditingController();
  final _ramal = TextEditingController();
  NivelUrgencia _urgenciaSelecionada = NivelUrgencia.normal;
  late TabController _tabController;
  int? _indiceExpandidoUsuario;

 @override
void initState() {
  super.initState();
  _tabController = TabController(length: 2, vsync: this);
  
  if (widget.usuario != null) {
    _nome.text = widget.usuario!.nome;
  }

  // Chamar a busca de dados ao iniciar
  _buscarChamadosDoBanco();
}

Future<void> _buscarChamadosDoBanco() async {
  try {
    final response = await Supabase.instance.client
        .from('chamados')
        .select()
        .order('urgencia', ascending: false);

    setState(() {
      bancoDeDadosGlobal = (response as List).map((item) {
        return Chamado(
          id: item['id_chamado'],
          setor: item['setor'],
          solicitante: item['solicitante'],
          problema: item['problema'],
          ramal: item['ramal'] ?? '',
          status: item['status'] ?? 'A iniciar',
          urgencia: NivelUrgencia.values[item['urgencia'] ?? 1],
          dataHora: item['created_at'] != null 
              ? DateTime.parse(item['created_at']) 
              : DateTime.now(),
        );
      }).toList();
    });
  } catch (e) {
    print("Erro ao buscar dados: $e");
  }
}

  void _reabrirChamado(Chamado chamado) {
    final obsCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Reabrir Chamado"),
        content: TextField(
          controller: obsCtrl,
          decoration: const InputDecoration(labelText: "Motivo da reabertura"),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () {
              if (obsCtrl.text.isNotEmpty) {
                setState(() {
                  chamado.status = 'A iniciar';
                  chamado.dataFinalizacao = null;
                  chamado.observacoes = List.from(chamado.observacoes)
                    ..add("Reaberto por ${widget.usuario?.nome ?? 'usuário'} em ${DateTime.now().day}/${DateTime.now().month}: ${obsCtrl.text}");
                });
                Navigator.pop(ctx);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Por favor, descreva o motivo.")),
                );
              }
            },
            child: const Text("Enviar"),
          )
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    // Acessando a lista global diretamente
    final int abertos = bancoDeDadosGlobal.where((c) => c.status != 'Finalizado').length;
    final int finalizados = bancoDeDadosGlobal.where((c) => c.status == 'Finalizado').length;
    final int total = abertos + finalizados;
    final double proporcaoFinalizados = (total == 0) ? 0.0 : finalizados / total;

    return Container(
      padding: const EdgeInsets.all(16.0),
      color: Colors.grey[100],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Resumo Geral de Chamados",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Abertos: $abertos", style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
              Text("Finalizados: $finalizados", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              Text("Total: $total", style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: proporcaoFinalizados,
            minHeight: 12,
            borderRadius: BorderRadius.circular(6),
            backgroundColor: Colors.orange.withOpacity(0.3),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 90,
        leadingWidth: 350, 
        leading: Row(
          children: [
            // Esse valor '30' deve ser o mesmo que você usou no Admin
            const SizedBox(width: 30), 
            Expanded(
              child: Image.asset(
                'assets/images/logo-prefeitura4.png',
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
        title: const Text("HelpDesk - Usuário"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            tooltip: 'Sair',
            onPressed: () => Navigator.pushReplacementNamed(context, '/'),
          )
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.add_circle_outline), text: "Novo Chamado"),
            Tab(icon: Icon(Icons.history), text: "Histórico"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ABA 1: NOVO CHAMADO
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
          children: [
            // Espaço para Logo na Dashboard
          Card(
              color: Colors.white,
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    TextField(controller: _nome, decoration: const InputDecoration(labelText: "Nome Solicitante", border: OutlineInputBorder()), readOnly: widget.usuario != null),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _setorSelecionado,
                      decoration: const InputDecoration(labelText: "Setor", border: OutlineInputBorder()),
                      items: setoresGlobal.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                      onChanged: (v) => setState(() => _setorSelecionado = v!),
                    ),
                    const SizedBox(height: 10),
                    TextField(controller: _ramal, decoration: const InputDecoration(labelText: "Ramal", border: OutlineInputBorder())),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<NivelUrgencia>(
                      value: _urgenciaSelecionada,
                      decoration: const InputDecoration(labelText: "Nível de Urgência", border: OutlineInputBorder()),
                      items: NivelUrgencia.values.map((u) => DropdownMenuItem(value: u, child: Text(u.name.toUpperCase()))).toList(),
                      onChanged: (v) => setState(() => _urgenciaSelecionada = v!),
                    ),
                    const SizedBox(height: 10),
                    TextField(controller: _problema, decoration: const InputDecoration(labelText: "Descreva o Problema", border: OutlineInputBorder()), maxLines: 3),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                      onPressed: _enviarChamado, 
                      child: const Text("ABRIR CHAMADO")
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
          // ABA 2: HISTÓRICO
          ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: bancoDeDadosGlobal.where((c) => c.solicitante == _nome.text && _nome.text.isNotEmpty).length,
            itemBuilder: (ctx, i) {
              final lista = bancoDeDadosGlobal.where((c) => c.solicitante == _nome.text && _nome.text.isNotEmpty).toList();
              final c = lista[i];
              return Card(
                elevation: 4,
                margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                color: c.status == 'Finalizado' ? Colors.grey[200] : const Color(0xFFFFE6CB),
                child: ExpansionTile(
                  key: GlobalKey(),
                  initiallyExpanded: i == _indiceExpandidoUsuario,
                  onExpansionChanged: (expanded) {
                    setState(() {
                      _indiceExpandidoUsuario = expanded ? i : null;
                    });
                  },
                  leading: CircleAvatar(
                    backgroundColor: c.status == 'Finalizado'
                        ? Colors.green
                        : (c.status == 'Em andamento' || c.status == 'Aguardando Confirmação' ? Colors.amber : Colors.red),
                    child: Icon(
                      c.status == 'Finalizado' ? Icons.check : Icons.priority_high,
                      color: Colors.white
                    ),
                  ),
                  title: Text("#${c.id} - ${c.problema}"),
                  subtitle: Text("Status: ${c.status} | Urgência: ${c.urgencia.name.toUpperCase()}"),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(15.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("📅 Abertura: ${c.dataHora.day}/${c.dataHora.month}/${c.dataHora.year} às ${c.dataHora.hour}:${c.dataHora.minute.toString().padLeft(2, '0')}"),
                          if (c.dataFinalizacao != null)
                            Text("🏁 Finalizado em: ${c.dataFinalizacao!.day}/${c.dataFinalizacao!.month}/${c.dataFinalizacao!.year} às ${c.dataFinalizacao!.hour}:${c.dataFinalizacao!.minute.toString().padLeft(2, '0')}"),
                          Text("🏷️ Classificação: ${c.classificacao ?? 'Não definida'}"),
                          Text("👨‍🔧 Técnico: ${c.tecnico ?? 'Não atribuído'}"),
                          const SizedBox(height: 8),
                          const Text("📝 Problema:", style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(c.problema),
                          if (c.observacoes.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            const Text("⚠️ Histórico de Reaberturas:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                            ...c.observacoes.map((obs) => Padding(
                              padding: const EdgeInsets.only(left: 8.0, top: 4.0),
                              child: Text("• $obs", style: const TextStyle(fontSize: 13)),
                            )),
                          ],
                          if (c.justificativas.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            const Text("⏳ Histórico de Pendências (Técnico):", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                            ...c.justificativas.map((just) => Padding(
                              padding: const EdgeInsets.only(left: 8.0, top: 4.0),
                              child: Text("• $just", style: const TextStyle(fontSize: 13)),
                            )),
                          ],
                          const SizedBox(height: 15),
                          
                          // 3. O BOTÃO DE ATENDER / FINALIZAR
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (c.status == 'A iniciar')
                                ElevatedButton.icon(
                                  onPressed: () => setState(() {
                                    c.status = 'Finalizado';
                                    c.dataFinalizacao = DateTime.now();
                                  }),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                  icon: const Icon(Icons.cancel, color: Colors.white),
                                  label: const Text("Cancelar", style: TextStyle(color: Colors.white)),
                                ),
                                
                              if (c.status == 'Aguardando Confirmação') ...[
                                ElevatedButton(
                                  onPressed: () => setState(() {
                                    c.status = 'Finalizado';
                                    c.dataFinalizacao = DateTime.now();
                                  }),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                  child: const Text("Solucionado", style: TextStyle(color: Colors.white)),
                                ),
                                const SizedBox(width: 10),
                                ElevatedButton(
                                  onPressed: () => _reabrirChamado(c),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                                  child: const Text("Reabrir", style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
);
            },
          ),
        ],
      ),
    );
  }
}

// --- VISÃO DO SUPORTE (T.I.) ---
class DashboardSuporte extends StatefulWidget {
  final Usuario? usuario;
  const DashboardSuporte({super.key, this.usuario});
  @override
  State<DashboardSuporte> createState() => _DashboardSuporteState();
}

class _DashboardSuporteState extends State<DashboardSuporte> {
    int? _indiceExpandido;

  void _definirClassificacao(Chamado chamado) {
    String? selecionada = chamado.classificacao;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Definir Classificação"),
        content: DropdownButtonFormField<String>(
          value: selecionada,
          items: listaClassificacoes.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
          onChanged: (v) => selecionada = v,
          decoration: const InputDecoration(labelText: "Classificação"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () {
              setState(() {
                chamado.classificacao = selecionada;
              });
              Navigator.pop(ctx);
            },
            child: const Text("Salvar"),
          )
        ],
      ),
    );
  }

  // 1. FUNÇÃO DE REABRIR
  void _reabrirChamado(Chamado chamado) {
    final obsCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Reabrir Chamado"),
        content: TextField(
          controller: obsCtrl,
          decoration: const InputDecoration(labelText: "Motivo da reabertura"),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () {
              if (obsCtrl.text.isNotEmpty) {
                setState(() {
                  chamado.status = 'A iniciar';
                  chamado.dataFinalizacao = null;
                  chamado.observacoes = List.from(chamado.observacoes)
                    ..add("Reaberto por ${widget.usuario?.nome ?? 'usuário'} em ${DateTime.now().day}/${DateTime.now().month}: ${obsCtrl.text}");
                });
                Navigator.pop(ctx);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Por favor, descreva o motivo.")),
                );
              }
            },
            child: const Text("Enviar"),
          )
        ],
      ),
    );
  }

  // 3. FUNÇÃO DE REGISTRAR PENDÊNCIA
  void _registrarPendencia(Chamado chamado) {
    final justCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Registrar Pendência"),
        content: TextField(
          controller: justCtrl,
          decoration: const InputDecoration(labelText: "Motivo da pendência (ex: Aguardando peça)"),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () {
              if (justCtrl.text.isNotEmpty) {
                setState(() {
                  chamado.status = 'Pendente';
                  chamado.justificativas = List.from(chamado.justificativas)
                    ..add("${DateTime.now().day}/${DateTime.now().month} - ${justCtrl.text}");
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text("Salvar Pendência"),
          )
        ],
      ),
    );
  }
 
  // 2. FUNÇÃO DAS CORES
  Color _getCorPrazo(DateTime dataAbertura) {
    final diff = DateTime.now().difference(dataAbertura).inHours;
    if (diff > 48) return Colors.red;
    if (diff > 24) return Colors.yellow;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 90,
          leadingWidth: 350,
          leading: Row(
            children: [
              const SizedBox(width: 30),
              Expanded(
                child: Image.asset(
                  'assets/images/logo-prefeitura4.png',
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ),
          title: const Text("T.I Suporte"),
          centerTitle: true,
          backgroundColor: const Color(0xFFF15A22),
          actions: [
            IconButton(
              icon: const Icon(Icons.exit_to_app),
              tooltip: 'Sair',
              onPressed: () => Navigator.pushReplacementNamed(context, '/'),
            )
          ],
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(icon: Icon(Icons.list), text: "Fila de Atendimento"),
              Tab(icon: Icon(Icons.history), text: "Histórico"),
            ],
          ),
        ),
        body: TabBarView(
          children: [ _buildListaChamadosSuporte(false), _buildListaChamadosSuporte(true), ]
        ),
      ),
    );
  }


  Widget _buildListaChamadosSuporte(bool finalizados) {
    final lista = bancoDeDadosGlobal
        .where((c) => finalizados ? c.status == 'Finalizado' : c.status != 'Finalizado')
        .toList();

    return ListView.builder(
      itemCount: lista.length,
      itemBuilder: (ctx, i) {
        final chamado = lista[i];
        final bool isAdmin = widget.usuario?.perfil == TipoPerfil.admin;
        final bool isResponsavel = chamado.tecnico == widget.usuario?.nome;
        final bool temTecnico = chamado.tecnico != null && chamado.tecnico!.isNotEmpty;

        return Card(
          elevation: 4,
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          color: chamado.status == 'Finalizado' ? Colors.grey[200] : const Color(0xFFFFE6CB),
          child: ExpansionTile(
            key: GlobalKey(), 
            initiallyExpanded: i == _indiceExpandido,
            onExpansionChanged: (bool expandido) {
              setState(() {
                _indiceExpandido = expandido ? i : null;
              });
            },
            leading: CircleAvatar(
              backgroundColor: chamado.status == 'Finalizado'
                  ? Colors.green
                  : (chamado.status == 'Em andamento' || chamado.status == 'Aguardando Confirmação' || chamado.status == 'Pendente' ? Colors.amber : Colors.red),
              child: Icon(
                chamado.status == 'Finalizado' ? Icons.check : Icons.priority_high,
                color: Colors.white,
              ),
            ),
            title: Text("#${chamado.id} | ${chamado.setor} - ${chamado.solicitante}",
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("Status: ${chamado.status} | Urgência: ${chamado.urgencia.name.toUpperCase()}"),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("📅 Abertura: ${chamado.dataHora.day}/${chamado.dataHora.month}/${chamado.dataHora.year} às ${chamado.dataHora.hour}:${chamado.dataHora.minute.toString().padLeft(2, '0')}"),
                    if (chamado.dataFinalizacao != null)
                      Text("🏁 Finalizado em: ${chamado.dataFinalizacao!.day}/${chamado.dataFinalizacao!.month}/${chamado.dataFinalizacao!.year} às ${chamado.dataFinalizacao!.hour}:${chamado.dataFinalizacao!.minute.toString().padLeft(2, '0')}"),
                    Text("🏷️ Classificação: ${chamado.classificacao ?? 'Não definida'}"),
                    Text("👨‍🔧 Técnico: ${chamado.tecnico ?? 'Não atribuído'}"),
                    const SizedBox(height: 8),
                    const Text("📝 Problema:", style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(chamado.problema),
                    if (chamado.observacoes.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      const Text("⚠️ Histórico de Reaberturas:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                      ...chamado.observacoes.map((obs) => Padding(
                        padding: const EdgeInsets.only(left: 8.0, top: 4.0),
                        child: Text("• $obs", style: const TextStyle(fontSize: 13)),
                      )),
                    ],
                    if (chamado.justificativas.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      const Text("⏳ Histórico de Pendências (Técnico):", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                      ...chamado.justificativas.map((just) => Padding(
                        padding: const EdgeInsets.only(left: 8.0, top: 4.0),
                        child: Text("• $just", style: const TextStyle(fontSize: 13)),
                      )),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        // --- STATUS: A INICIAR ---
                        if (chamado.status == 'A iniciar' && (!temTecnico || isAdmin))
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => setState(() {
                                chamado.status = 'Em andamento';
                                chamado.tecnico = widget.usuario?.nome;
                              }),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                              child: Text(temTecnico ? "Assumir" : "Atender", style: const TextStyle(color: Colors.white)),
                            ),
                          ),

                        // --- STATUS: EM ANDAMENTO ---
                        if (chamado.status == 'Em andamento') ...[
                          if (isResponsavel || isAdmin) ...[
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => setState(() => chamado.status = 'Aguardando Confirmação'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  padding: EdgeInsets.zero,
                                ),
                                child: const Text("Finalizar", style: TextStyle(color: Colors.white, fontSize: 12)),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => _definirClassificacao(chamado),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.purple,
                                  padding: EdgeInsets.zero,
                                ),
                                child: const Text("Classificar", style: TextStyle(color: Colors.white, fontSize: 12)),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => _registrarPendencia(chamado),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blueGrey,
                                  padding: EdgeInsets.zero,
                                ),
                                child: const Text("Pendência", style: TextStyle(color: Colors.white, fontSize: 12)),
                              ),
                            ),
                          ] else ...[
                            Expanded(
                              child: Column(
                                children: [
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.red[50],
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      "Em atendimento por: ${chamado.tecnico}",
                                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () => _confirmarTrocaTecnico(chamado),
                                      icon: const Icon(Icons.sync, color: Colors.white, size: 16),
                                      label: const Text("Assumir", style: TextStyle(color: Colors.white, fontSize: 12)),
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ]
                        ],

                        // --- STATUS: PENDENTE ---
                        if (chamado.status == 'Pendente') ...[
                          if (isResponsavel || isAdmin)
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => setState(() => chamado.status = 'Em andamento'),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                                child: const Text("Retomar Atendimento", style: TextStyle(color: Colors.white, fontSize: 12)),
                              ),
                            )
                          else
                            Expanded(
                              child: Column(
                                children: [
                                  Text(
                                    "Pendente com: ${chamado.tecnico}",
                                    style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontSize: 12),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 5),
                                  ElevatedButton(
                                    onPressed: () => _confirmarTrocaTecnico(chamado),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                                    child: const Text("Assumir", style: TextStyle(color: Colors.white, fontSize: 11)),
                                  ),
                                ],
                              ),
                            )
                        ],

                        // --- STATUS: AGUARDANDO CONFIRMAÇÃO ---
                        if (chamado.status == 'Aguardando Confirmação') ...[
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => setState(() {
                                chamado.status = 'Finalizado';
                                chamado.dataFinalizacao = DateTime.now();
                              }),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                              child: const Text("Solucionado", style: TextStyle(color: Colors.white)),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _reabrirChamado(chamado),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                              child: const Text("Reabrir", style: TextStyle(color: Colors.white)),
                            ),
                          ),
                        ],
                      ],
                    )
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // FUNÇÃO QUE RESOLVE O ERRO:
  void _confirmarTrocaTecnico(dynamic chamado) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Assumir Chamado"),
        content: Text("Deseja transferir o atendimento de ${chamado.tecnico} para o seu nome?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () {
              setState(() {
                chamado.tecnico = widget.usuario?.nome;
                chamado.status = 'Em andamento';
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
            child: const Text("Confirmar Troca", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
} // <--- FIM DA CLASSE DASHBOARD SUPORTE


 class DashboardAdmin extends StatefulWidget {
  const DashboardAdmin({super.key});

  @override
  State<DashboardAdmin> createState() => _DashboardAdminState();
}

class _DashboardAdminState extends State<DashboardAdmin> with SingleTickerProviderStateMixin {
  int? _indiceAtivoExpandido;   // Controla a aba Ativos
  int? _indiceHistoricoExpandido; // Controla a aba Histórico
  int? _indiceExpandidoAdmin;
  late TabController _tabController;
  final _novoSetorCtrl = TextEditingController();
  final _novaClassificacaoCtrl = TextEditingController();
  DateTimeRange? _periodoSelecionado;
  String? _idChamadoExpandido;
  String _setorFiltro = 'Todos';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _novoSetorCtrl.dispose();
    _novaClassificacaoCtrl.dispose();
    super.dispose();
  }

  void _adicionarSetor() {
    if (_novoSetorCtrl.text.isNotEmpty && !setoresGlobal.contains(_novoSetorCtrl.text)) {
      setState(() {
        setoresGlobal.add(_novoSetorCtrl.text);
        _novoSetorCtrl.clear();
      });
    }
  }

  void _removerSetor(String setor) {
    if (setor != 'Geral') {
      setState(() {
        setoresGlobal.remove(setor);
      });
    }
  }

  void _adicionarClassificacao() {
    if (_novaClassificacaoCtrl.text.isNotEmpty && !listaClassificacoes.contains(_novaClassificacaoCtrl.text)) {
      setState(() {
        listaClassificacoes.add(_novaClassificacaoCtrl.text);
        _novaClassificacaoCtrl.clear();
      });
    }
  }

  void _removerClassificacao(String item) {
    setState(() {
      listaClassificacoes.remove(item);
    });
  }

  void _editarSetor(String setorAntigo) {
    final _setorEditCtrl = TextEditingController(text: setorAntigo);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Editar Setor"),
        content: TextField(
          controller: _setorEditCtrl,
          decoration: const InputDecoration(labelText: "Novo nome do setor"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () {
              final novoNome = _setorEditCtrl.text;
              if (novoNome.isNotEmpty && !setoresGlobal.contains(novoNome)) {
                setState(() {
                  final index = setoresGlobal.indexOf(setorAntigo);
                  if (index != -1) {
                    setoresGlobal[index] = novoNome;
                  }
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text("Salvar"),
          ),
        ],
      ),
    );
  }

  void _editarChamado(Chamado c) {
    final problemaCtrl = TextEditingController(text: c.problema);
    final ramalCtrl = TextEditingController(text: c.ramal);
    
    String setorSelecionado = c.setor;
    if (!setoresGlobal.contains(setorSelecionado) && setoresGlobal.isNotEmpty) {
      setorSelecionado = setoresGlobal.first;
    }

    String statusSelecionado = c.status;
    NivelUrgencia urgenciaSelecionada = c.urgencia;
    String? classificacaoSelecionada = c.classificacao;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Editar Chamado"),
        content: StatefulBuilder(
          builder: (context, setStateDialog) {
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: setorSelecionado,
                    items: setoresGlobal.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (v) => setStateDialog(() => setorSelecionado = v!),
                    decoration: const InputDecoration(labelText: "Setor"),
                  ),
                  TextField(controller: ramalCtrl, decoration: const InputDecoration(labelText: "Ramal")),
                  TextField(controller: problemaCtrl, decoration: const InputDecoration(labelText: "Problema"), maxLines: 3),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: statusSelecionado,
                    items: ['A iniciar', 'Em andamento', 'Pendente', 'Aguardando Confirmação', 'Finalizado']
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) => setStateDialog(() => statusSelecionado = v!),
                    decoration: const InputDecoration(labelText: "Status"),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<NivelUrgencia>(
                    value: urgenciaSelecionada,
                    items: NivelUrgencia.values
                        .map((u) => DropdownMenuItem(value: u, child: Text(u.name.toUpperCase())))
                        .toList(),
                    onChanged: (v) => setStateDialog(() => urgenciaSelecionada = v!),
                    decoration: const InputDecoration(labelText: "Urgência"),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: classificacaoSelecionada,
                    items: listaClassificacoes.map((cls) => DropdownMenuItem(value: cls, child: Text(cls))).toList(),
                    onChanged: (v) => setStateDialog(() => classificacaoSelecionada = v),
                    decoration: const InputDecoration(labelText: "Classificação"),
                    hint: const Text("Selecione..."),
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () {
              setState(() {
                final index = bancoDeDadosGlobal.indexOf(c);
                if (index != -1) {
                  DateTime? dataFim = c.dataFinalizacao;
                  if (statusSelecionado == 'Finalizado' && dataFim == null) {
                    dataFim = DateTime.now();
                  } else if (statusSelecionado != 'Finalizado') {
                    dataFim = null;
                  }

                  bancoDeDadosGlobal[index] = Chamado(
                    id: c.id,
                    setor: setorSelecionado,
                    solicitante: c.solicitante,
                    problema: problemaCtrl.text,
                    ramal: ramalCtrl.text,
                    dataHora: c.dataHora,
                    dataFinalizacao: dataFim,
                    urgencia: urgenciaSelecionada,
                    status: statusSelecionado,
                    tecnico: c.tecnico,
                    classificacao: classificacaoSelecionada,
                    observacoes: c.observacoes,
                    justificativas: c.justificativas,
                  );
                  _ordenarPorPrioridade();
                }
              });
              Navigator.pop(ctx);
            },
            child: const Text("Salvar"),
          )
        ],
      ),
    );
  }

  void _editarUsuario(Usuario u) {
    final nomeCtrl = TextEditingController(text: u.nome);
    final loginCtrl = TextEditingController(text: u.login);
    final senhaCtrl = TextEditingController();
    TipoPerfil perfilSelecionado = u.perfil;
    SetorTecnico? setorTecnicoSelecionado = u.setorTecnico;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Editar Usuário"),
        content: StatefulBuilder(
          builder: (context, setStateDialog) {
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nomeCtrl, decoration: const InputDecoration(labelText: "Nome")),
                  TextField(controller: loginCtrl, decoration: const InputDecoration(labelText: "Login")),
                  TextField(controller: senhaCtrl, decoration: const InputDecoration(labelText: "Nova Senha (opcional)")),
                  DropdownButtonFormField<TipoPerfil>(
                    value: perfilSelecionado,
                    items: const [
                      DropdownMenuItem(value: TipoPerfil.usuario, child: Text("Usuário Comum")),
                      DropdownMenuItem(value: TipoPerfil.suporte, child: Text("Técnico/Suporte")),
                      DropdownMenuItem(value: TipoPerfil.admin, child: Text("ADM")),
                    ],
                    // Removi o primeiro onChanged que estava duplicado
                    onChanged: (v) {
                      setStateDialog(() {
                        perfilSelecionado = v!;
                        if (perfilSelecionado != TipoPerfil.suporte) {
                          setorTecnicoSelecionado = null;
                        }
                      });
                    },
                    decoration: const InputDecoration(labelText: "Cargo"),
                  ), // Aqui estava fechando com um ')' extra que quebrava o código
                  
                  if (perfilSelecionado == TipoPerfil.suporte) ...[
                    const SizedBox(height: 10),
                    DropdownButtonFormField<SetorTecnico>(
                      value: setorTecnicoSelecionado,
                      items: SetorTecnico.values.map((s) => DropdownMenuItem(
                        value: s, 
                        child: Text(s == SetorTecnico.sistemas ? 'Sistemas' : 'Hardwares')
                      )).toList(),
                      onChanged: (v) => setStateDialog(() => setorTecnicoSelecionado = v),
                      decoration: const InputDecoration(labelText: "Setor do Técnico"),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () {
              setState(() {
                final index = usuariosMock.indexOf(u);
                if (index != -1) {
                  usuariosMock[index] = Usuario(
                    login: loginCtrl.text,
                    senha: senhaCtrl.text.isNotEmpty ? senhaCtrl.text : u.senha,
                    nome: nomeCtrl.text,
                    perfil: perfilSelecionado,
                    setorTecnico: perfilSelecionado == TipoPerfil.suporte ? setorTecnicoSelecionado : null,
                    primeiroAcesso: u.primeiroAcesso,
                    dataCadastro: u.dataCadastro,
                    ativo: u.ativo,
                  );
                }
              });
              Navigator.pop(ctx);
            },
            child: const Text("Salvar"),
          )
        ],
      ),
    );
  }

  void _criarChamadoAdmin() {
    String setorSelecionado = setoresGlobal.isNotEmpty ? setoresGlobal.first : '';
    String? classificacaoSelecionada;
    final nomeCtrl = TextEditingController();
    final ramalCtrl = TextEditingController();
    final problemaCtrl = TextEditingController();
    NivelUrgencia urgencia = NivelUrgencia.normal;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Novo Chamado (ADM)"),
        content: StatefulBuilder(
          builder: (context, setStateDialog) {
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nomeCtrl, decoration: const InputDecoration(labelText: "Solicitante")),
                  DropdownButtonFormField<String>(
                    value: setorSelecionado,
                    items: setoresGlobal.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (v) => setStateDialog(() => setorSelecionado = v!),
                    decoration: const InputDecoration(labelText: "Setor"),
                  ),
                  TextField(controller: ramalCtrl, decoration: const InputDecoration(labelText: "Ramal")),
                  TextField(controller: problemaCtrl, decoration: const InputDecoration(labelText: "Problema"), maxLines: 3),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<NivelUrgencia>(
                    value: urgencia,
                    items: NivelUrgencia.values.map((u) => DropdownMenuItem(value: u, child: Text(u.name.toUpperCase()))).toList(),
                    onChanged: (v) => setStateDialog(() => urgencia = v!),
                    decoration: const InputDecoration(labelText: "Urgência"),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: classificacaoSelecionada,
                    items: listaClassificacoes.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) => setStateDialog(() => classificacaoSelecionada = v),
                    decoration: const InputDecoration(labelText: "Classificação"),
                    hint: const Text("Selecione..."),
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () {
              setState(() {
                bancoDeDadosGlobal.add(Chamado(
                  id: _gerarNovoId(),
                  setor: setorSelecionado,
                  solicitante: nomeCtrl.text,
                  problema: problemaCtrl.text,
                  ramal: ramalCtrl.text,
                  dataHora: DateTime.now(),
                  urgencia: urgencia,
                  classificacao: classificacaoSelecionada,
                ));
                _ordenarPorPrioridade();
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Chamado criado!")));
            },
            child: const Text("Criar"),
          )
        ],
      ),
    );
  }

  void _criarNovoUsuario() {
    String nome = '';
    String login = '';
    String senha = '';
    TipoPerfil perfil = TipoPerfil.usuario;
    SetorTecnico? setorTecnico;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Criar Novo Usuário"),
        content: StatefulBuilder(
          builder: (context, setStateDialog) {
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(decoration: const InputDecoration(labelText: "Nome"), onChanged: (v) => nome = v),
                  TextField(decoration: const InputDecoration(labelText: "Login"), onChanged: (v) => login = v),
                  TextField(decoration: const InputDecoration(labelText: "Senha Temporária"), onChanged: (v) => senha = v),
                  DropdownButtonFormField<TipoPerfil>(
                    value: perfil,
                    items: const [
                      DropdownMenuItem(value: TipoPerfil.usuario, child: Text("Usuário Comum")),
                      DropdownMenuItem(value: TipoPerfil.suporte, child: Text("Técnico/Suporte")),
                      DropdownMenuItem(value: TipoPerfil.admin, child: Text("ADM")),
                    ],
                    onChanged: (v) => setStateDialog(() => perfil = v!),
                    decoration: const InputDecoration(labelText: "Cargo"),
                  ), // O ERRO ESTAVA AQUI: Haviam dois parênteses ))
                  
                  if (perfil == TipoPerfil.suporte) ...[
                    const SizedBox(height: 10),
                    DropdownButtonFormField<SetorTecnico>(
                      value: setorTecnico,
                      items: SetorTecnico.values.map((s) => DropdownMenuItem(
                        value: s, 
                        child: Text(s == SetorTecnico.sistemas ? 'Sistemas' : 'Hardwares')
                      )).toList(),
                      onChanged: (v) => setStateDialog(() => setorTecnico = v),
                      decoration: const InputDecoration(labelText: "Setor do Técnico"),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () {
              setState(() {
                // CORREÇÃO: Adicionando apenas UM usuário com ou sem setor técnico
                usuariosMock.add(Usuario(
                  login: login, 
                  senha: senha, 
                  nome: nome, 
                  perfil: perfil, 
                  primeiroAcesso: true,
                  setorTecnico: perfil == TipoPerfil.suporte ? setorTecnico : null,
                ));
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Usuário criado!")));
            },
            child: const Text("Salvar"),
          )
        ],
      ),
    );
  }

 @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 90,
        // Diminuímos o leadingWidth para não roubar espaço do título
        leadingWidth: 350, 
        leading: Row(
          children: [
            // Esse SizedBox cria o espaço na esquerda (o empurrão)
            // Aumente ou diminua o 'width' para ajustar a posição
            const SizedBox(width: 30), 
            
            // A imagem agora respira sem ser espremida
            Expanded(
              child: Image.asset(
                'assets/images/logo-prefeitura4.png',
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
        title: const Text("HelpDesk - Admin"),
        centerTitle: true,
        backgroundColor: const Color(0xFFF15A22),
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            tooltip: 'Sair',
            onPressed: () => Navigator.pushReplacementNamed(context, '/'),
          )
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.list), text: "ATIVOS"),
            Tab(icon: Icon(Icons.history), text: "HISTÓRICO"),
            Tab(icon: Icon(Icons.people), text: "USUÁRIOS"),
            Tab(icon: Icon(Icons.category), text: "SETORES"),
            Tab(icon: Icon(Icons.label), text: "CLASSIFICAÇÕES"),
            Tab(icon: Icon(Icons.bar_chart), text: "INDICADORES"),
          ],
        ),
      ),
      floatingActionButton: (_tabController.index == 0 || _tabController.index == 2)
      ? FloatingActionButton(
          onPressed: _tabController.index == 2 ? _criarNovoUsuario : _criarChamadoAdmin,
          backgroundColor: const Color(0xFFF15A22),
          child: Icon(
            _tabController.index == 2 ? Icons.person_add : Icons.add_task,
            color: Colors.white,
          ),
        )
      : null,
      body: Column(
  children: [
    // LÓGICA DE VISIBILIDADE: 
    // O dashboard só aparece se o index for 0 (Ativos) ou 1 (Histórico)
    if (_tabController.index == 0 || _tabController.index == 1)
      _buildDashboard(),

    Expanded(
        child: TabBarView(
          controller: _tabController,
          children: [
            // ABA 1: CHAMADOS ATIVOS
            _buildListaChamadosAdmin(false),

            // ABA 2: HISTÓRICO
            _buildListaChamadosAdmin(true),

            // ABA 3: USUÁRIOS
            ListView.builder(
              itemCount: usuariosMock.length,
              itemBuilder: (ctx, i) {
                final u = usuariosMock[i];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: ExpansionTile(
                    key: GlobalKey(), 
                    initiallyExpanded: i == _indiceExpandidoAdmin,
                    onExpansionChanged: (bool expandido) {
                      setState(() {
                        _indiceExpandidoAdmin = expandido ? i : null;
                      });
                    },
                    // EM VEZ DE ListTile, USE AS PROPRIEDADES ABAIXO:
                    leading: CircleAvatar(
                      backgroundColor: u.ativo ? Colors.green : Colors.grey,
                      child: const Icon(Icons.person, color: Colors.white),
                    ),
                    title: Text(
                      u.nome,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    // Apaguei a linha repetida que estava aqui
                    subtitle: Text("Login: ${u.login} | Perfil: ${u.perfil.name.toUpperCase()}" +
                        (u.perfil == TipoPerfil.suporte && u.setorTecnico != null
                            ? " - ${u.setorTecnico == SetorTecnico.sistemas ? 'Sistemas' : 'Hardwares'}"
                            : "")),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _editarUsuario(u),
                        ),
                        Switch(
                          value: u.ativo,
                          onChanged: (val) => setState(() => u.ativo = val),
                        ),
                      ],
                    ),
                    // CONTEÚDO QUE APARECE AO ABRIR:
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text("Cadastro: ${u.dataCadastro.day}/${u.dataCadastro.month}/${u.dataCadastro.year}"),
                      ),
                    ],
                  ),
                );
              },
            ),

            // ABA 4: SETORES
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: TextField(controller: _novoSetorCtrl, decoration: const InputDecoration(labelText: "Novo Setor", border: OutlineInputBorder()))),
                      const SizedBox(width: 10),
                      ElevatedButton(onPressed: _adicionarSetor, child: const Text("Adicionar")),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView.builder(
                      itemCount: setoresGlobal.length,
                      itemBuilder: (ctx, i) {
                        final s = setoresGlobal[i];
                        return Card(
                          child: ListTile(
                            title: Text(s),
                            trailing: s == 'Geral' ? null : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _editarSetor(s)),
                                const SizedBox(width: 8),
                                IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _removerSetor(s)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // ABA 5: CLASSIFICAÇÕES
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: TextField(controller: _novaClassificacaoCtrl, decoration: const InputDecoration(labelText: "Nova Classificação", border: OutlineInputBorder()))),
                      const SizedBox(width: 10),
                      ElevatedButton(onPressed: _adicionarClassificacao, child: const Text("Adicionar")),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView.builder(
                      itemCount: listaClassificacoes.length,
                      itemBuilder: (ctx, i) {
                        final item = listaClassificacoes[i];
                        return Card(
                          child: ListTile(
                            title: Text(item),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _removerClassificacao(item),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  // ABA 6: INDICADORES
                  _buildIndicadores(),
                ], // Fim do children do TabBarView
              ), // Fim do TabBarView
            ), // Fim do Expanded
          ], // Fim do children da Column (Linha 1231)
        ), // Fim da Column (Linha 1230)
      ); // Fim do Scaffold (Linha 1180)
  }

  Map<String, Map<String, int>> _processarDadosGrafico() {
    Map<String, Map<String, int>> dados = {};

    if (_periodoSelecionado == null) return dados;

    final inicio = _periodoSelecionado!.start;
    final fim = _periodoSelecionado!.end.add(const Duration(days: 1));

    for (var c in bancoDeDadosGlobal) {
      if (c.dataHora.isAfter(inicio) && c.dataHora.isBefore(fim)) {
        if (_setorFiltro != 'Todos' && c.setor != _setorFiltro) continue;

        final mes = "${c.dataHora.month.toString().padLeft(2, '0')}/${c.dataHora.year}";

        if (!dados.containsKey(mes)) {
          dados[mes] = {'Abertos': 0, 'Andamento': 0, 'Finalizados': 0};
        }

        if (c.status == 'A iniciar' || c.status == 'Aberto' || c.status == 'Novo') {
          dados[mes]!['Abertos'] = dados[mes]!['Abertos']! + 1;
        } else if (c.status == 'Em andamento' || c.status == 'Aguardando Confirmação' || c.status == 'Pendente') {
          dados[mes]!['Andamento'] = dados[mes]!['Andamento']! + 1;
        } else if (c.status == 'Finalizado') {
          dados[mes]!['Finalizados'] = dados[mes]!['Finalizados']! + 1;
        }
      }
    }
    return dados;
  }

  Future<void> _exportarRelatorioPDF(DateTime? dataInicio, DateTime? dataFim) async {
    final pdf = pw.Document();

    // 1. Filtragem dos dados
    final listaParaPdf = bancoDeDadosGlobal.where((c) {
      bool bateData = true;
      if (dataInicio != null && dataFim != null) {
        bateData = c.dataHora.isAfter(dataInicio) &&
            c.dataHora.isBefore(dataFim.add(const Duration(days: 1)));
      }
      bool bateSetor = _setorFiltro == 'Todos' || c.setor == _setorFiltro;
      return bateData && bateSetor;
    }).toList();

      // 2. Contagem para o gráfico
    // 2. Contagem para o gráfico (usando .trim() e .toLowerCase() para evitar erros de digitação)
    final abertos = listaParaPdf.where((c) {
      final s = c.status.toLowerCase().trim();
      return s == 'aberto' || s == 'a iniciar'; 
    }).length.toDouble();

    final andamento = listaParaPdf.where((c) {
      final s = c.status.toLowerCase().trim();
      return s == 'andamento' || s == 'em andamento' || s == 'pendente' || s == 'aguardando confirmação';
    }).length.toDouble();

    final finalizados = listaParaPdf.where((c) {
      final s = c.status.toLowerCase().trim();
      return s == 'finalizado' || s == 'concluído';
    }).length.toDouble();

    final maxVal = [abertos, andamento, finalizados].reduce((curr, next) => curr > next ? curr : next);
    final maxY = maxVal > 0 ? maxVal.toInt() : 1;
    final yTicks = [0, (maxY / 2).ceil(), maxY];

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Relatorio de Desempenho - Setor: $_setorFiltro',
                  style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
              if (dataInicio != null && dataFim != null)
                pw.Text(
                  'Período: ${DateFormat('dd/MM/yyyy').format(dataInicio)} até ${DateFormat('dd/MM/yyyy').format(dataFim)}',
                  style: pw.TextStyle(fontSize: 12, fontStyle: pw.FontStyle.italic),
                ),
              pw.SizedBox(height: 30),
              
              // Gráfico de Barras com nomes de eixos compatíveis
              pw.Container(
                height: 300,
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(width: 1, color: PdfColors.grey300),
                ),
                padding: const pw.EdgeInsets.all(10),
                child: pw.Chart(
                  grid: pw.CartesianGrid(
                    xAxis: pw.FixedAxis(
                      [0, 1, 2],
                      buildLabel: (v) {
                        if (v == 0) return pw.Text('Abertos');
                        if (v == 1) return pw.Text('Andamento');
                        return pw.Text('Finalizados');
                      },
                    ),
                    // REMOVIDO o 'dividers: true' para não dar erro
                    yAxis: pw.FixedAxis([0, 5, 10, 15, 20, 50, 100]), 
                  ),
                  datasets: [
                    pw.BarDataSet(
                      color: PdfColors.red300,
                      width: 60,
                      data: [pw.LineChartValue(0, abertos)],
                    ),
                    pw.BarDataSet(
                      color: PdfColors.amber300,
                      width: 60,
                      data: [pw.LineChartValue(1, andamento)],
                    ),
                    pw.BarDataSet(
                      color: PdfColors.green300,
                      width: 60,
                      data: [pw.LineChartValue(2, finalizados)],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Container(width: 12, height: 12, color: PdfColors.red300),
                  pw.SizedBox(width: 5),
                  pw.Text('Abertos'),
                  pw.SizedBox(width: 20),
                  pw.Container(width: 12, height: 12, color: PdfColors.amber300),
                  pw.SizedBox(width: 5),
                  pw.Text('Andamento'),
                  pw.SizedBox(width: 20),
                  pw.Container(width: 12, height: 12, color: PdfColors.green300),
                  pw.SizedBox(width: 5),
                  pw.Text('Finalizados'),
                ],
              ),
              
              pw.SizedBox(height: 50),
              pw.Text('Resumo Geral:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text('Total de chamados: ${listaParaPdf.length}'),
              pw.Text('Abertos: ${abertos.toInt()}'),
              pw.Text('Em Andamento: ${andamento.toInt()}'),
              pw.Text('Finalizados: ${finalizados.toInt()}'),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  Widget _buildBarraAcoesSetor() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Text('Setor: ', style: TextStyle(fontWeight: FontWeight.bold)),
          DropdownButton<String>(
            value: _setorFiltro,
            items: ['Todos', 'RH', 'TI']
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (novoValor) => setState(() => _setorFiltro = novoValor!),
          ),
          const Spacer(),
          IconButton(icon: const Icon(Icons.picture_as_pdf, color: Colors.red), onPressed: () => _exportarRelatorioPDF(_periodoSelecionado?.start, _periodoSelecionado?.end)),
        ],
      ),
    );
  }

  Widget _buildGraficoMensalSetores() {
    final dados = _processarDadosGrafico();
    if (dados.isEmpty) return const SizedBox.shrink();

    int maxValor = 0;
    for (var mes in dados.values) {
      for (var val in mes.values) {
        if (val > maxValor) maxValor = val;
      }
    }
    if (maxValor == 0) maxValor = 1;

    final chavesOrdenadas = dados.keys.toList()..sort((a, b) {
      final partsA = a.split('/');
      final partsB = b.split('/');
      final dateA = DateTime(int.parse(partsA[1]), int.parse(partsA[0]));
      final dateB = DateTime(int.parse(partsB[1]), int.parse(partsB[0]));
      return dateA.compareTo(dateB);
    });

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: chavesOrdenadas.length,
      itemBuilder: (ctx, i) {
        final mes = chavesOrdenadas[i];
        final valores = dados[mes]!;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _barraGrafico(valores['Abertos'] ?? 0, maxValor, Colors.red, "A iniciar"),
                  const SizedBox(width: 4),
                  _barraGrafico(valores['Andamento'] ?? 0, maxValor, Colors.amber, "Em andamento / A confirmar"),
                  const SizedBox(width: 4),
                  _barraGrafico(valores['Finalizados'] ?? 0, maxValor, Colors.green, "Finalizado"),
                ],
              ),
              const SizedBox(height: 8),
              Text(mes, style: const TextStyle(fontSize: 12)),
            ],
          ),
        );
      },
    );
  }

  Widget _barraGrafico(int valor, int max, Color cor, String label) {
    final double altura = (valor / max) * 200;
    return Tooltip(
      message: "$label: $valor",
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$valor', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          Container(
            width: 15,
            height: altura > 0 ? altura : 1,
            color: cor,
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(width: 12, height: 12, color: color),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildIndicadores() {
    int total = 0;
    int finalizados = 0;
    Map<String, int> porTecnico = {};

    if (_periodoSelecionado != null) {
      final inicio = _periodoSelecionado!.start;
      final fim = _periodoSelecionado!.end.add(const Duration(days: 1));

      final filtrados = bancoDeDadosGlobal.where((c) {
        final dataOk = c.dataHora.isAfter(inicio) && c.dataHora.isBefore(fim);
        final setorOk = _setorFiltro == 'Todos' || c.setor == _setorFiltro;
        return dataOk && setorOk;
        }).toList();

total = filtrados.length;
finalizados = filtrados.where((c) => c.status == 'Finalizado').length;

      for (var c in filtrados) {
        if (c.tecnico != null && c.tecnico!.isNotEmpty) {
          porTecnico.update(c.tecnico!, (val) => val + 1, ifAbsent: () => 1);
        }
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.date_range, color: Color(0xFFF15A22)),
            title: Text(_periodoSelecionado == null
                ? "Selecione o Período"
                : "${_periodoSelecionado!.start.day}/${_periodoSelecionado!.start.month}/${_periodoSelecionado!.start.year} até ${_periodoSelecionado!.end.day}/${_periodoSelecionado!.end.month}/${_periodoSelecionado!.end.year}"),
            trailing: ElevatedButton(
              onPressed: () async {
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                  locale: const Locale('pt', 'BR'),
                );
                if (picked != null) {
                  setState(() {
                    _periodoSelecionado = picked;
                  });
                }
              },
              child: const Text("Filtrar"),
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (_periodoSelecionado != null) ...[
          Row(
            children: [
              Expanded(child: _cardIndicador("Total no Período", total.toString(), Colors.blue)),
              const SizedBox(width: 10),
              Expanded(child: _cardIndicador("Realizados", finalizados.toString(), Colors.green)),
            ],
          ),
          const SizedBox(height: 10),
          _buildIndicadoresPorSetorTI(),
          const SizedBox(height: 20),
          const Text("Atendimentos por Técnico", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          if (porTecnico.isEmpty)
            const Center(child: Text("Nenhum registro de técnico no período."))
          else
            ...porTecnico.entries.map((entry) {
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.person, color: Color(0xFFF15A22)),
                  title: Text(entry.key),
                  trailing: Text("${entry.value}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ),
              );
            }),
          _buildBarraAcoesSetor(), // MANTENHA ESTA CHAMADA
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(Colors.red, "A iniciar"),
              const SizedBox(width: 15),
              _buildLegendItem(Colors.amber, "Em andamento / A confirmar"),
              const SizedBox(width: 15),
              _buildLegendItem(Colors.green, "Finalizado"),
            ],
          ),
          const SizedBox(height: 10),
          // APAGUE A LINHA ABAIXO (ela é a duplicada):
          // _buildBarraAcoesSetor(), 
          
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Center(child: Text("Desempenho Mensal - $_setorFiltro", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
          ),
          SizedBox(
            height: 250,
            child: _buildGraficoMensalSetores(),
          ),
        ] else ...[
          const SizedBox(height: 40),
          const Center(child: Text("Selecione um período para visualizar os indicadores.")),
        ],
      ],
    );
  }

  Widget _cardIndicador(String titulo, String valor, Color cor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cor.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Text(valor, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: cor)),
          Text(titulo, style: TextStyle(color: cor, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildIndicadoresPorSetorTI() {
    if (_periodoSelecionado == null) {
      return const SizedBox.shrink();
    }

    int sistemasCount = 0;
    int hardwaresCount = 0;

    final inicio = _periodoSelecionado!.start;
    final fim = _periodoSelecionado!.end.add(const Duration(days: 1));

    final chamadosNoPeriodoFinalizados = bancoDeDadosGlobal.where((c) {
      return c.status == 'Finalizado' && c.dataHora.isAfter(inicio) && c.dataHora.isBefore(fim);
    }).toList();

    for (var chamado in chamadosNoPeriodoFinalizados) {
      if (chamado.tecnico != null) {
        try {
          final tecnico = usuariosMock.firstWhere((u) => u.nome == chamado.tecnico);
          if (tecnico.setorTecnico == SetorTecnico.sistemas) {
            sistemasCount++;
          } else if (tecnico.setorTecnico == SetorTecnico.hardwares) {
            hardwaresCount++;
          }
        } catch (e) {
          // Ignora caso o técnico não seja encontrado
        }
      }
    }

    return Row(
      children: [
        Expanded(child: _cardIndicador("Sistemas (Finalizados)", sistemasCount.toString(), Colors.deepPurple)),
        const SizedBox(width: 10),
        Expanded(child: _cardIndicador("Hardwares (Finalizados)", hardwaresCount.toString(), Colors.teal)),
      ],
    );
  }

  // --- COLE ESTE NOVO BLOCO AQUI ---
  Widget _buildDashboard() {
    final lista = bancoDeDadosGlobal;
    int total = lista.length;
    int abertos = lista.where((c) => c.status != 'Finalizado').length;
    int finalizados = lista.where((c) => c.status == 'Finalizado').length;
    double progresso = total > 0 ? finalizados / total : 0.0;

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _itemMiniDash("Total", total.toString(), Colors.black),
              _itemMiniDash("Abertos", abertos.toString(), Colors.red),
              _itemMiniDash("Finalizados", finalizados.toString(), Colors.green),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progresso,
              backgroundColor: Colors.grey[200],
              color: const Color(0xFFF15A22),
              minHeight: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemMiniDash(String label, String valor, Color cor) {
    return Column(
      children: [
        Text(valor, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cor)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  void _definirClassificacao(Chamado chamado) {
    String? selecionada = chamado.classificacao;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Definir Classificação"),
        content: DropdownButtonFormField<String>(
          value: selecionada,
          items: listaClassificacoes.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
          onChanged: (v) => selecionada = v,
          decoration: const InputDecoration(labelText: "Classificação"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () {
              setState(() {
                chamado.classificacao = selecionada;
              });
              Navigator.pop(ctx);
            },
            child: const Text("Salvar"),
          )
        ],
      ),
    );
  }

  void _reabrirChamado(Chamado chamado) {
    final obsCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Reabrir Chamado"),
        content: TextField(
          controller: obsCtrl,
          decoration: const InputDecoration(labelText: "Motivo da reabertura"),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () {
              if (obsCtrl.text.isNotEmpty) {
                setState(() {
                  chamado.status = 'A iniciar';
                  chamado.dataFinalizacao = null;
                  chamado.observacoes = List.from(chamado.observacoes)
                    ..add("Reaberto por Admin em ${DateTime.now().day}/${DateTime.now().month}: ${obsCtrl.text}");
                });
                Navigator.pop(ctx);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Por favor, descreva o motivo.")),
                );
              }
            },
            child: const Text("Enviar"),
          )
        ],
      ),
    );
  }

  void _registrarPendencia(Chamado chamado) {
    final justCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Registrar Pendência"),
        content: TextField(
          controller: justCtrl,
          decoration: const InputDecoration(labelText: "Motivo da pendência (ex: Aguardando peça)"),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () {
              if (justCtrl.text.isNotEmpty) {
                setState(() {
                  chamado.status = 'Pendente';
                  chamado.justificativas = List.from(chamado.justificativas)
                    ..add("${DateTime.now().day}/${DateTime.now().month} - ${justCtrl.text}");
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text("Salvar Pendência"),
          )
        ],
      ),
    );
  }
  // --- FIM DO BLOCO NOVO ---

  Widget _buildListaChamadosAdmin(bool finalizados) {
  final lista = bancoDeDadosGlobal
      .where((c) => finalizados ? c.status == 'Finalizado' : c.status != 'Finalizado')
      .toList();

  return ListView.builder(
    itemCount: lista.length,
    itemBuilder: (ctx, i) {
      final c = lista[i];
      
      // Define qual variável de controle usar dependendo da aba
      bool estaExpandido = finalizados 
          ? i == _indiceHistoricoExpandido 
          : i == _indiceAtivoExpandido;

      return Card(
        elevation: 4,
        margin: const EdgeInsets.all(10),
        child: ExpansionTile(
          key: GlobalKey(),
          initiallyExpanded: estaExpandido,
          onExpansionChanged: (bool expandido) {
            setState(() {
              if (finalizados) {
                _indiceHistoricoExpandido = expandido ? i : null;
              } else {
                _indiceAtivoExpandido = expandido ? i : null;
              }
            });
          },
          leading: CircleAvatar(
            backgroundColor: c.status == 'Finalizado'
                ? Colors.green
                : (c.status == 'Em andamento' || c.status == 'Aguardando Confirmação' || c.status == 'Pendente'
                    ? Colors.amber
                    : Colors.red),
            child: Icon(
              c.status == 'Finalizado' ? Icons.check : Icons.priority_high,
              color: Colors.white,
            ),
          ),
          title: Text("#${c.id} | ${c.setor} - ${c.solicitante}"),
          subtitle: Text("Status: ${c.status} | Urgência: ${c.urgencia.name.toUpperCase()}"),
          children: [
            Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      "📅 Abertura: ${c.dataHora.day}/${c.dataHora.month}/${c.dataHora.year} às ${c.dataHora.hour}:${c.dataHora.minute.toString().padLeft(2, '0')}"),
                  if (c.dataFinalizacao != null)
                    Text("🏁 Finalizado em: ${c.dataFinalizacao!.day}/${c.dataFinalizacao!.month}/${c.dataFinalizacao!.year} às ${c.dataFinalizacao!.hour}:${c.dataFinalizacao!.minute.toString().padLeft(2, '0')}"),
                  Text("🏷️ Classificação: ${c.classificacao ?? 'Não definida'}"),
                  Text("👨‍🔧 Técnico: ${c.tecnico ?? 'Não atribuído'}"),
                  const SizedBox(height: 8),
                  const Text("📝 Problema:",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(c.problema),
                  if (c.observacoes.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Text("⚠️ Histórico de Reaberturas:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                    ...c.observacoes.map((obs) => Padding(
                      padding: const EdgeInsets.only(left: 8.0, top: 4.0),
                      child: Text("• $obs", style: const TextStyle(fontSize: 13)),
                    )),
                  ],
                  if (c.justificativas.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Text("⏳ Histórico de Pendências (Técnico):", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                    ...c.justificativas.map((just) => Padding(
                      padding: const EdgeInsets.only(left: 8.0, top: 4.0),
                      child: Text("• $just", style: const TextStyle(fontSize: 13)),
                    )),
                  ],
                  const SizedBox(height: 15),
                  
                  // Botões de Ação do Admin (Atender, Finalizar, etc.)
                  if (!finalizados)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        if (c.status == 'A iniciar')
                          Expanded( // Adicionado Expanded aqui para manter padrão
                            child: ElevatedButton(
                              onPressed: () => setState(() {
                                c.status = 'Em andamento';
                                c.tecnico = 'Admin';
                              }),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                              child: const Text("Atender", style: TextStyle(color: Colors.white)),
                            ),
                          ),
                          
                        if (c.status == 'Em andamento') ...[
                          Expanded( // Botão Finalizar
                            child: ElevatedButton(
                              onPressed: () => setState(() => c.status = 'Aguardando Confirmação'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                padding: EdgeInsets.zero,
                              ),
                              child: const Text("Finalizar", style: TextStyle(color: Colors.white, fontSize: 12)),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Expanded( // Adicionado Expanded para o Classificar
                            child: ElevatedButton(
                              onPressed: () => _definirClassificacao(c),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purple,
                                padding: EdgeInsets.zero, // Padding zero ajuda a caber o texto
                              ),
                              child: const Text("Classificar", style: TextStyle(color: Colors.white, fontSize: 12)),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Expanded( // Adicionado Expanded para o Pendência
                            child: ElevatedButton(
                              onPressed: () => _registrarPendencia(c),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueGrey,
                                padding: EdgeInsets.zero,
                              ),
                              child: const Text("Pendência", style: TextStyle(color: Colors.white, fontSize: 12)),
                            ),
                          ),
                        ],
                        
                        if (c.status == 'Pendente') ...[
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => setState(() => c.status = 'Em andamento'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                              child: const Text("Retomar", style: TextStyle(color: Colors.white)),
                            ),
                          ),
                        ],
                        
                        if (c.status == 'Aguardando Confirmação') ...[
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => setState(() {
                                c.status = 'Finalizado';
                                c.dataFinalizacao = DateTime.now();
                              }),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                              child: const Text("Solucionado", style: TextStyle(color: Colors.white)),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _reabrirChamado(c),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                              child: const Text("Reabrir", style: TextStyle(color: Colors.white)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  const SizedBox(height: 15),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _editarChamado(c),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue),
                        icon: const Icon(Icons.edit, color: Colors.white),
                        label: const Text("Editar",
                            style: TextStyle(color: Colors.white)),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: () =>
                            setState(() => bancoDeDadosGlobal.remove(c)),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red),
                        icon: const Icon(Icons.delete, color: Colors.white),
                        label: const Text("Excluir",
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
} // Fecha o _buildListaChamadosAdmin
} // Fecha a classe _DashboardAdminState