// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.5.0;

contract Votacion {

    struct Voto{
        Propuesta propuesta;
        Opcion opcion;
        uint platicaCambio; // dinero por cambio de opcion
    }

    struct Votante{
        string nombreVotante;
        bool votoEmitido;
    }

    enum Propuesta {Propuesta0, Propuesta1}

    enum Opcion {
        Altamente_de_acuerdo,
        De_acuerdo,
        Neutral,
        Desacuerdo,
        Altamente_en_desacuerdo
    }

    string public textProp1;
    string public textProp2;
    uint public numVotos = 0; //confirmar si acumula platicaCambio de opcion y especificar
    uint private totalPlatica;
    address private dirIniciador;
    address payable public dirPresidente;
    uint public numVotantesRegistrados = 0;
    address payable public dirVicepresidente;
    
    mapping(address => Voto) private votos;
    mapping(uint => uint) private numVotProp0;
    mapping(uint => uint) private numVotProp1;
    mapping(address => Votante) public registroVotantes;
    
    enum Estado { Creada, Votando, Finalizada }
	Estado public estado;

	constructor (
        address payable _dirVicepresidente,
        string memory _propuesta1,
        string memory _propuesta2) public {
            require(
                msg.sender != _dirVicepresidente,
                "No puede ocupar ambos cargos simultaneamente"
            );
            estado = Estado.Creada;
            dirPresidente = msg.sender;
            textProp1 = _propuesta1;
            textProp2 = _propuesta2;
            dirVicepresidente = _dirVicepresidente;                      
    }

	modifier soloOficiales() {
		require(
            msg.sender == dirPresidente || msg.sender == dirVicepresidente,
            "Solo personal autorizado puede ejecutar esta funcion"
        );
		_;
	}

	modifier estadoVotacion(Estado _estado) {
		require(
            estado == _estado,
            "En este momento no puede realizar esta actividad"
        );
		_;
	}

    modifier propuestaValida (uint _prop) {
        require ((_prop == 0 || _prop == 1),
        "La unicas propuestas disponibles son la 0 y la 1")
        _;
    }

    modifier opcionValida (uint _op) {
        require ((_op >= 0 && _op <= 4),
        "Solo opciones entre cero y cuatro")
        _;
    }

    error valorIncorrecto(uint pagado, uint requerido);

    event votanteRegistrado(address Votante); //Verificar tipo
    event votacionIniciada();
    event votacionHecha(address Votante); //Verificar tipo
    
    function registrarVotante(address _dirVotante, string memory _nombreVotante)
        public
        estadoVotacion(Estado.Creada)
        soloOficiales
    {
        require(
            (_dirVotante != dirPresidente) && (_dirVotante != dirVicepresidente),
            "El presidente y vicepresidente no pueden votar"
        );
        Votante memory voto;
        voto.nombreVotante = _nombreVotante;
        voto.votoEmitido = false;
        registroVotantes[_dirVotante] = voto;
        numVotantesRegistrados++;
        emit votanteRegistrado(_dirVotante);
    }

    function iniciarVotacion()
        public
        estadoVotacion(Estado.Creada)
        soloOficiales
    {
        estado = Estado.Votando;
        dirIniciador = msg.sender;
        emit votacionIniciada();
    }

    function votar(Propuesta _propuesta, Opcion _opcion)
        public payable
        estadoVotacion(Estado.Votando)
        propuestaValida (_propuesta)
        opcionValida (_opcion)
        returns (bool votoEmitido)
    {
        bool found = false;
        // Comprueba si el votante está registrado
        if (bytes(registroVotantes[msg.sender].nombreVotante).length != 0){
            Voto memory voto;
            // si ya votó
            if (registroVotantes[msg.sender].votoEmitido){
                // trae el voto del votante
                voto = votos[msg.sender];
                // comprueba pago correcto para cambiar de opinion
                if (msg.value != voto.platicaCambio * (1 ether))
                    revert valorIncorrecto({
                        pagado: msg.value,
                        requerido: voto.platicaCambio * (1 ether)
                    });
                // require(
                //     msg.value == voto.platicaCambio * (1 ether),
                //     "Monto incorrecto para cambiar su opcion"
                // );
                require(
                    _propuesta == voto.propuesta,
                    "Puede cambiar de opcion pero no de propuesta"
                );
                // si tenia la propuesta0 y elige una opción nueva
                if (_propuesta == Propuesta.Propuesta0 && _opcion != voto.opcion){
                    // decrementa votos de la opcion anterior
                    // incrementa los de la nueva y actualiza nueva opcion
                    numVotProp0[uint(voto.opcion)]--;
                    numVotProp0[uint(_opcion)]++;
                    voto.opcion = _opcion;
                }
                // si tenia la propuesta1 y elige una opción nueva
                if (_propuesta == Propuesta.Propuesta1 && _opcion != voto.opcion){
                    numVotProp1[uint(voto.opcion)]--;
                    numVotProp1[uint(_opcion)]++;
                    voto.opcion = _opcion;
                }
                // aumenta el precio para siguiente cambio
                voto.platicaCambio ++;
                // reemplaza voto completo con nuevos valores
                votos[msg.sender] = voto;
                // cobra por el cambio y acumula
                totalPlatica += msg.value;
            }
            // si es la primera vez que vota
            else {
                require(
                    msg.value == 0,
                    "La primera votacion es gratis (valor 0)"
                );
                // cambie el estado a que ya votó
                registroVotantes[msg.sender].votoEmitido = true;

                voto.propuesta = _propuesta;
                voto.opcion = _opcion;
                voto.platicaCambio = 1;
                votos[msg.sender] = voto;

                numVotos++;
                // incrementa los votos de la opcion de la propuesta
                if (_propuesta == Propuesta.Propuesta0){
                    numVotProp0[uint(_opcion)]++;
                } else {
                    numVotProp1[uint(_opcion)]++;
                }
            }

            // si el usuario ya existe devuelve true
            // de lo contrario false
            found = true;
        }
        emit votacionHecha(msg.sender);
        return found;
    }
    
    // Cerrar votacion. Solo presi o vice
    // la cierra el contrario al que abrio
    function cerrarVotacion()
        public
        estadoVotacion(Estado.Votando)
        soloOficiales
    {
        require(
            msg.sender != dirIniciador,
            ""
        );
        estado = Estado.Finalizada;
        dirVicepresidente.transfer(totalPlatica / 2);
        dirPresidente.transfer(totalPlatica / 2);
    }

    function result(Propuesta _propuesta, Opcion _opcion)
    public view estadoVotacion(Estado.Finalizada) returns (uint res){
        if (_propuesta == Propuesta.Propuesta0) {
            return numVotProp0[uint(_opcion)];
        } else {
            return numVotProp1[uint(_opcion)];
        }
    }
}