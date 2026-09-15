const { Pool } = require("pg");

let pool;

function getPool() {
  if (!pool) {
    pool = new Pool({
      host: process.env.DB_HOST,
      port: Number(process.env.DB_PORT || 5432),
      database: process.env.DB_NAME || "postgres",
      user: process.env.DB_USER,
      password: process.env.DB_PASSWORD,
      ssl: process.env.DB_SSL === "false" ? false : { rejectUnauthorized: false },
      max: 3,
      idleTimeoutMillis: 10000,
    });
  }
  return pool;
}

/**
 * Busca o cliente pelo CPF/CNPJ. Tenta tanto o valor exatamente como foi
 * informado quanto a versão só com dígitos, já que a aplicação principal não
 * normaliza esse campo ao cadastrar (mesmo valor que foi digitado no
 * cadastro é o que fica salvo em `cliente.cpf_cnpj`).
 */
async function buscarClientePorCpf(cpfComoInformado, cpfSomenteDigitos) {
  const client = await getPool().connect();
  try {
    const result = await client.query(
      `SELECT id, nome, email, deletado_em
       FROM cliente
       WHERE cpf_cnpj = $1 OR cpf_cnpj = $2
       LIMIT 1`,
      [cpfComoInformado, cpfSomenteDigitos]
    );
    return result.rows[0] || null;
  } finally {
    client.release();
  }
}

module.exports = { getPool, buscarClientePorCpf };
