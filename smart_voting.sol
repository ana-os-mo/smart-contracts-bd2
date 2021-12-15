// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.5.0;

contract Votacion {
    //-----------------estructuras---------------------
    struct Voto{
        Propuesta propuesta;
        Opcion opcion;
        uint platicaCambio;
    }

    struct Votante{
        string nombreVotante;
        bool votoEmitido;
    }

    //-----------------enumeracion---------------------

    enum Propuesta {Propuesta0, Propuesta1}

    enum Estado { Creada, Votando, Finalizada }
	Estado public estado;

    enum Opcion {
        Altamente_de_acuerdo,
        De_acuerdo,
        Neutral,
        Desacuerdo,
        Altamente_en_desacuerdo
    }

    //-----------------mappings---------------------
    
    mapping(address => Voto) private votos;
    mapping(uint => uint) private numVotProp0;
    mapping(uint => uint) private numVotProp1;
    mapping(address => Votante) public registroVotantes;

    //-----------------otras variables---------------------

    string public textProp1;
    string public textProp2;
    uint public numVotos = 0;
    uint private totalPlatica;
    address private dirIniciador;
    address payable public dirPresidente;
    uint public numVotantesRegistrados = 0;
    address payable public dirVicepresidente;

    //-----------------eventos---------------------

    event votanteRegistrado(address Votante); //Verificar tipo
    event votacionIniciada();
    event votacionHecha(address Votante); //Verificar tipo
    event votacionFinalizada(); 

    // Quien crea la votacion queda con el rol de presidente
    // y designa un vicepresidente
	constructor (address payable _dirVicepresidente,string memory _textProp0,string memory _textProp1) public {
        require(
            // presi y vice no pueden ser iguales
            msg.sender != _dirVicepresidente,
            "No puede ocupar ambos cargos simultaneamente"
        );
        // la votacion queda en estado creada (0)
        estado = Estado.Creada;
        // creador de la votacion
        dirPresidente = msg.sender;
        textProp1 = _textProp0;
        textProp2 = _textProp1;
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
        require (
            _prop == 0 || _prop == 1,
            "La unicas propuestas disponibles son la 0 y la 1"
        );
        _;
    }

    modifier opcionValida (uint _op) {
        require ((_op >= 0 && _op <= 4),
        "Solo opciones entre cero y cuatro"
        );
        _;
    }

    // registro de usuarios
    function addVoter(address _dirVotante, string memory _nombreVotante)
        public
        estadoVotacion(Estado.Creada)
        soloOficiales
    {   
        // ni presi ni vice se pueden inscribir para votar
        require(
            (_dirVotante != dirPresidente) && (_dirVotante != dirVicepresidente),
            "El presidente y vicepresidente no pueden votar"
        );
        // se registra al votante y se crea un objeto
        // tipo voto para usar en el estado de votando
        Votante memory voto;
        voto.nombreVotante = _nombreVotante;
        voto.votoEmitido = false;
        registroVotantes[_dirVotante] = voto;
        numVotantesRegistrados++;
        emit votanteRegistrado(_dirVotante);
    }

    // Inician las votaciones. Solo presi o vice
    // Guarda registro del iniciador
    function iniciarVotacion()
        public
        estadoVotacion(Estado.Creada)
        soloOficiales
    {
        estado = Estado.Votando;
        dirIniciador = msg.sender;
        emit votacionIniciada();
    }

    // emision de votos. Solo votantes registrados
    function votar(Propuesta _propuesta, Opcion _opcion)
        public payable
        estadoVotacion(Estado.Votando)
        // propuestaValida(_propuesta) opcionValida(_opcion)
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
                // comprueba pago correcto por cambiar de opinion
                require(
                    msg.value == voto.platicaCambio * (1 ether),
                    "Monto incorrecto para cambiar su opcion"
                );
                // comprueba que no cambie de propuesta
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

                // Si elige la mismo opcion no se actualiza el voto
                // pero igual se le cobra

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
                // si el usuario ya existe devuelve true
                // de lo contrario false
                found = true;
                emit votacionHecha(msg.sender);
                return found;
            }
            
        }
        // si usuario no registra retorna false sin dejar votar
        return found;
    }
    
    // Cerrar votacion. Solo presi o vice
    // la cierra el contrario al que abrio
    function cerrarVotacion()
        public
        estadoVotacion(Estado.Votando)
        soloOficiales
    {   
        // solo el que NO abrio la votacion puede cerrarla
        require(
            msg.sender != dirIniciador,
            "Solo el otro oficial autorizado puede cerrar la votacion"
        );
        estado = Estado.Finalizada;
        // reparticion de ganancias por cambios de votacion 50/50
        dirVicepresidente.transfer(totalPlatica / 2);
        dirPresidente.transfer(totalPlatica / 2);
        emit votacionFinalizada();
    }

    function reporteFinal(Propuesta _propuesta, Opcion _opcion)
    public view
    estadoVotacion(Estado.Finalizada)
    returns (uint res){
        if (_propuesta == Propuesta.Propuesta0) {
            return numVotProp0[uint(_opcion)];
        } else {
            return numVotProp1[uint(_opcion)];
        }
    }
}