const jwt = require("jsonwebtoken");
const crypto = require("crypto");

/**
 * Normaliza a chave privada vinda de uma App Setting. Ferramentas que
 * armazenam variáveis de ambiente em uma única linha costumam escapar as
 * quebras de linha do PEM como "\n" literais — aqui a gente devolve isso
 * para quebras de linha reais antes de assinar.
 */
function normalizarChave(valor) {
  return valor.includes("\\n") ? valor.replace(/\\n/g, "\n") : valor;
}

/**
 * Emite um access token no mesmo formato que `EfetuarLoginUseCaseImpl` gera
 * no backend Quarkus (mesmo issuer, mesma chave RS256, claim `groups` com o
 * perfil) — para que o `smallrye.jwt.verify.*` da API valide sem nenhuma
 * mudança de configuração do lado Java.
 */
function emitirTokenCliente(cliente) {
  const privateKey = process.env.JWT_PRIVATE_KEY;
  if (!privateKey) {
    throw new Error("JWT_PRIVATE_KEY não configurada nas App Settings da Function.");
  }

  const issuer = process.env.JWT_ISSUER || "oficina-api-interna";
  const expiresInSeconds = Number(process.env.JWT_EXPIRES_IN_SECONDS || 28800);

  const payload = {
    iss: issuer,
    sub: cliente.id,
    upn: cliente.email || `cpf:${cliente.cpfNormalizado}`,
    groups: ["CLIENTE"],
    cliente_id: cliente.id,
    jti: crypto.randomUUID(),
  };

  const token = jwt.sign(payload, normalizarChave(privateKey), {
    algorithm: "RS256",
    expiresIn: expiresInSeconds,
  });

  return { token, expiresIn: expiresInSeconds };
}

module.exports = { emitirTokenCliente };
