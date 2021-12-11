// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

contract Votacion {

    // Estructs --------------------------------------

    // bytes 32 es mas barato que un string

    // MODIFICAR CONSTRUCTOR CON ESTA ESTRUCTURA
    struct Propuesta {
        string textPropuesta;
        uint altamente_de_acuerdo;
        uint de_acuerdo;
        uint neutral;
        uint desacuerdo;
        uint altamente_en_desacuerdo;
    }

    // Mappings --------------------------------------


    // Otras variables -------------------------------

    address public presidente;
    address public vicePresidente;

    Propuesta[] public propuestas;

    enum Estado { Creada, Votando, Finalizada }
    Estado public estado;

    // Eventos ----------------------------------------

    // Modificadores ----------------------------------

    error verificarPresiVice (string mensaje);

    // -----------------------------------------------

    constructor (

        address _vicePresidente,
        string memory _propuesta1,
        string memory _propuesta2

    ) {

        presidente = msg.sender;
        vicePresidente = _vicePresidente;

        if (presidente == vicePresidente)
            revert verificarPresiVice({
                mensaje: "El presidente y el vicepresidente deben ser diferentes"
            });

        propuestas.push(Propuesta({
            textPropuesta: _propuesta1,
            conteoVotos: 0
        }));
        propuestas.push(Propuesta({
            textPropuesta: _propuesta2,
            conteoVotos: 0
        }));

        estado = Estado.Creada;
    }
}