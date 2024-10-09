// SPDX-License-Identifier: MIT
// solium-disable security/no-assign-params

pragma solidity >=0.8.0 <0.9.0;

/// @title Elliptic curve operations on twist points on BN254-G2
/// @dev Adaptation of https://github.com/musalbas/solidity-BN256G2
library WitnetBN254 {

    using WitnetBN254 for Fq2;
    using WitnetBN254 for Point;
    
    uint256 internal constant F_MODULUS = 0x30644e72e131a029b85045b68181585d97816a916871ca8d3c208c16d87cfd47;
    
    uint256 internal constant TWIST_BX  = 0x2b149d40ceb8aaae81be18991be06ac3b5b4c5e559dbefa33267e6dc24a138e5;
    uint256 internal constant TWIST_BY  = 0x009713b03af0fed4cd2cafadeed8fdf4a74fa084e52d1852e4a2bd0685c315d2;
    
    // This is the generator negated, to use for pairing
    uint256 public constant G2_NEG_X_RE = 0x198E9393920D483A7260BFB731FB5D25F1AA493335A9E71297E485B7AEF312C2;
    uint256 public constant G2_NEG_X_IM = 0x1800DEEF121F1E76426A00665E5C4479674322D4F75EDADD46DEBD5CD992F6ED;
    uint256 public constant G2_NEG_Y_RE = 0x275dc4a288d1afb3cbb1ac09187524c7db36395df7be3b99e673b13a075a65ec;
    uint256 public constant G2_NEG_Y_IM = 0x1d9befcd05a5323e6da4d435f3b617cdb3af83285c2df711ef39c01571827f9d;

    struct Fq2 {
      uint256 real;
      uint256 imag;
    }
    
    struct Point {
      Fq2 x;
      Fq2 y;
    }

    function _addmod(uint256 a, uint256 b) private pure returns (uint256) {
      return uint256(addmod(a, b, F_MODULUS));
    }

    function _invmod(uint256 a) private view returns (uint256 _result) {
      bool _success;
      assembly {
        let _freemem := mload(0x40)
        mstore(_freemem, 0x20)
        mstore(add(_freemem,0x20), 0x20)
        mstore(add(_freemem,0x40), 0x20)
        mstore(add(_freemem,0x60), a)
        mstore(add(_freemem,0x80), sub(F_MODULUS, 2))
        mstore(add(_freemem,0xA0), F_MODULUS)
        _success := staticcall(sub(gas(), 2000), 5, _freemem, 0xC0, _freemem, 0x20)
        _result := mload(_freemem)
      }
      assert(_success);
    }

    function _mulmod(uint256 a, uint256 b) private pure returns (uint256) {
      return uint256(mulmod(a, b, F_MODULUS));
    }

    function _submod(uint256 a, uint256 b) private pure returns (uint256) {
      return uint256(addmod(a, F_MODULUS - b, F_MODULUS));
    }

    function add(Fq2 memory a, Fq2 memory b) internal pure returns (Fq2 memory) {
      return Fq2(
        _addmod(a.real, b.real),
        _addmod(a.imag, b.imag)
      );
    }

    function div(Fq2 memory d, Fq2 memory c) internal view returns (Fq2 memory) {
      return mul(d, inv(c));
    }

    function equals(Fq2 memory a, Fq2 memory b) internal pure returns (bool) {
      return (
        a.real == b.real
          && a.imag == b.imag
      );
    }

    function inv(Fq2 memory a) internal view returns (Fq2 memory) {
      uint256 _inv = _invmod(_addmod(_mulmod(a.imag, a.imag), _mulmod(a.real, a.real)));
      return Fq2(
        _mulmod(a.real, _inv),
        F_MODULUS - mulmod(a.imag, _inv, F_MODULUS)
      );
    }

    function mul(Fq2 memory a, Fq2 memory b) internal pure returns (Fq2 memory) {
      return Fq2(
        _submod(_mulmod(a.real, b.real), _mulmod(a.imag, b.imag)),
        _addmod(_mulmod(a.real, b.imag), _mulmod(a.imag, b.real))
      );
    }

    function mul(Fq2 memory a, uint256 k) internal pure returns (Fq2 memory) {
      return Fq2(
        _mulmod(a.real, k),
        _mulmod(a.imag, k)
      );
    }

    function sub(Fq2 memory a, Fq2 memory b) internal pure returns (Fq2 memory) {
      return Fq2(
        _submod(a.real, b.real),
        _submod(a.imag, b.imag)
      );
    }

    // WIP ...
}