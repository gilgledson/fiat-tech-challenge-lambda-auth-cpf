function normalizarCpf(cpf) {
  return String(cpf || "").replace(/\D/g, "");
}

function calcularDigitoVerificador(base, pesoInicial) {
  let soma = 0;
  for (let i = 0; i < base.length; i++) {
    soma += parseInt(base[i], 10) * (pesoInicial - i);
  }
  const resto = (soma * 10) % 11;
  return resto === 10 ? 0 : resto;
}

function cpfValido(cpf) {
  const digitos = normalizarCpf(cpf);

  if (digitos.length !== 11) return false;
  // Rejeita sequências como "00000000000", "11111111111" etc, que
  // passariam nos dígitos verificadores mas não são CPFs válidos.
  if (/^(\d)\1{10}$/.test(digitos)) return false;

  const digito1 = calcularDigitoVerificador(digitos.substring(0, 9), 10);
  const digito2 = calcularDigitoVerificador(digitos.substring(0, 9) + digito1, 11);

  return digitos.endsWith(`${digito1}${digito2}`);
}

module.exports = { cpfValido, normalizarCpf };
