const { app } = require("@azure/functions");
const { cpfValido, normalizarCpf } = require("../lib/cpfValidator");
const { buscarClientePorCpf } = require("../lib/db");
const { emitirTokenCliente } = require("../lib/jwt");

function json(status, body) {
  return { status, jsonBody: body };
}

app.http("authCpf", {
  methods: ["POST"],
  authLevel: "anonymous",
  route: "auth/cpf",
  handler: async (request, context) => {
    let body;
    try {
      body = await request.json();
    } catch {
      return json(400, { erro: 'Corpo da requisição inválido. Esperado JSON com o campo "cpf".' });
    }

    const cpfInformado = body && body.cpf;
    if (!cpfInformado || typeof cpfInformado !== "string") {
      return json(400, { erro: 'Campo "cpf" é obrigatório.' });
    }

    if (!cpfValido(cpfInformado)) {
      return json(400, { erro: "CPF inválido." });
    }

    const cpfDigits = normalizarCpf(cpfInformado);

    let cliente;
    try {
      cliente = await buscarClientePorCpf(cpfInformado.trim(), cpfDigits);
    } catch (err) {
      context.error("Falha ao consultar cliente no banco", err);
      return json(502, { erro: "Não foi possível validar o CPF no momento. Tente novamente." });
    }

    if (!cliente) {
      return json(404, { erro: "Cliente não encontrado para o CPF informado." });
    }

    if (cliente.deletado_em) {
      return json(403, { erro: "Cliente inativo." });
    }

    let token, expiresIn;
    try {
      ({ token, expiresIn } = emitirTokenCliente({
        id: cliente.id,
        email: cliente.email,
        cpfNormalizado: cpfDigits,
      }));
    } catch (err) {
      context.error("Falha ao emitir token", err);
      return json(500, { erro: "Não foi possível emitir o token no momento." });
    }

    return json(200, {
      access_token: token,
      token_type: "Bearer",
      expires_in: expiresIn,
    });
  },
});
