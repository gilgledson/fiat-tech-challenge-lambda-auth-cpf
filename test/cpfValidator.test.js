const test = require("node:test");
const assert = require("node:assert/strict");
const { cpfValido, normalizarCpf } = require("../src/lib/cpfValidator");

test("aceita CPF válido sem formatação", () => {
  assert.equal(cpfValido("52998224725"), true);
});

test("aceita CPF válido formatado", () => {
  assert.equal(cpfValido("529.982.247-25"), true);
});

test("rejeita CPF com dígito verificador incorreto", () => {
  assert.equal(cpfValido("52998224726"), false);
});

test("rejeita sequência de dígitos repetidos", () => {
  assert.equal(cpfValido("11111111111"), false);
});

test("rejeita CPF com tamanho errado", () => {
  assert.equal(cpfValido("123456789"), false);
});

test("rejeita entrada vazia ou nula", () => {
  assert.equal(cpfValido(""), false);
  assert.equal(cpfValido(null), false);
  assert.equal(cpfValido(undefined), false);
});

test("normalizarCpf remove pontuação", () => {
  assert.equal(normalizarCpf("529.982.247-25"), "52998224725");
});
