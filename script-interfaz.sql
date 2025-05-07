--JAVIER CONDE CORTES
--BASES DE DATOS
--BC4_2. Juego de preguntas y respuestas en ORACLE
--06/05/2025


-- Elimina la tabla si fue creada.
DROP TABLE ext_preguntas CASCADE CONSTRAINTS;
DROP TABLE JUGADA CASCADE CONSTRAINTS;
DROP TABLE PREGUNTA CASCADE CONSTRAINTS;
DROP TABLE TEMPJUGADA CASCADE CONSTRAINTS;
 
--CREATE OR REPLACE DIRECTORY dir_read AS 'C:\app\mine\product\21c\dbhomeXE\data';
--GRANT ALL ON DIRECTORY dir_read TO PUBLIC;
 
-- Tabla PREGUNTA: Contendrá la información de las preguntas.
CREATE TABLE PREGUNTA (
    id            NUMBER PRIMARY KEY,
    tematica      VARCHAR2(20),
    enunciado     VARCHAR2(100),
    a             VARCHAR2(30),
    b             VARCHAR2(30),
    c             VARCHAR2(30),
    d             VARCHAR2(30),
    respuesta     VARCHAR2(30)  -- Contendrá la respuesta correcta (por ejemplo, 'A', 'B', 'C' o 'D')
);
 
-- Tabla JUGADA registrará cada jugada del usuario.
CREATE TABLE JUGADA (
    fecha       TIMESTAMP,
    usuario     VARCHAR2(25),
    tematica    VARCHAR2(20),
    pregunta    VARCHAR2(100),
    eleccion    VARCHAR2(30),  -- Respuesta elegida por el usuario
    respuesta   VARCHAR2(30),  -- Respuesta correcta de la pregunta
    resultado   VARCHAR2(10)   -- Valores: 'ACIERTO' o 'FALLO'
);
 
CREATE TABLE TEMPJUGADA (
    fecha       TIMESTAMP,
    usuario     VARCHAR2(25),
    tematica    VARCHAR2(20),
    pregunta    VARCHAR2(100),
    respuesta   VARCHAR2(30)  -- Respuesta correcta de la pregunta
);
 
--creacion de tabla donde importaremos de los datos de las tablas que hemos creado.
 
-- Creación de la tabla externa para cargar los datos desde el archivo CSV
CREATE TABLE ext_preguntas (
    id             NUMBER,
    tematica       VARCHAR2(20),
    enunciado      VARCHAR2(100),
    a              VARCHAR2(30),
    b              VARCHAR2(30),
    c              VARCHAR2(30),
    d              VARCHAR2(30),
    respuesta      VARCHAR2(30)
)
ORGANIZATION EXTERNAL (
    TYPE ORACLE_LOADER
    DEFAULT DIRECTORY dir_read
    ACCESS PARAMETERS (
         RECORDS DELIMITED BY NEWLINE
         SKIP 1
         FIELDS TERMINATED BY ';'
         OPTIONALLY ENCLOSED BY '"'
         MISSING FIELD VALUES ARE NULL
         (
            id,
            tematica,
            enunciado,
            a,
            b,
            c,
            d,
            respuesta
         )
    )
    LOCATION ('preguntas.csv')
)
REJECT LIMIT UNLIMITED;
 
-- para copiar los datos en la tabla creada PREGUNTA
INSERT INTO PREGUNTA
SELECT * FROM ext_preguntas;
COMMIT;
 
-- fase 1
-- JUEGO
 
-- Bloque 1: Selección de pregunta y almacenamiento temporal
-- Ingreso inicial de datos
SET SERVEROUTPUT ON;
ACCEPT usuario PROMPT 'Ingrese su usuario: '
ACCEPT tematica PROMPT 'Ingrese la temática a jugar: '

-- (1) Bloque 1: Selección y muestra de la pregunta
DECLARE
    v_usuario           VARCHAR2(25) := '&usuario';
    v_tematica          VARCHAR2(20) := '&tematica';
    v_id                PREGUNTA.id%TYPE;
    v_enunciado         PREGUNTA.enunciado%TYPE;
    v_resp_a            PREGUNTA.a%TYPE;
    v_resp_b            PREGUNTA.b%TYPE;
    v_resp_c            PREGUNTA.c%TYPE;
    v_resp_d            PREGUNTA.d%TYPE;
    v_respuesta_correcta PREGUNTA.respuesta%TYPE;
BEGIN
    -- Seleccionar una pregunta aleatoria de la temática elegida
    SELECT id, enunciado, a, b, c, d, respuesta
      INTO v_id, v_enunciado, v_resp_a, v_resp_b, v_resp_c, v_resp_d, v_respuesta_correcta
    FROM ( SELECT *
             FROM PREGUNTA
            WHERE tematica = v_tematica
            ORDER BY DBMS_RANDOM.VALUE )
    WHERE ROWNUM = 1;
    
    -- Mostrar la pregunta y opciones
    DBMS_OUTPUT.PUT_LINE('-------------------------------------');
    DBMS_OUTPUT.PUT_LINE('Pregunta: ' || v_enunciado);
    DBMS_OUTPUT.PUT_LINE('A) ' || v_resp_a);
    DBMS_OUTPUT.PUT_LINE('B) ' || v_resp_b);
    DBMS_OUTPUT.PUT_LINE('C) ' || v_resp_c);
    DBMS_OUTPUT.PUT_LINE('D) ' || v_resp_d);
    DBMS_OUTPUT.PUT_LINE('-------------------------------------');

    -- Guardar la pregunta en TEMPJUGADA para usarla luego
    DELETE FROM TEMPJUGADA WHERE usuario = v_usuario;
    INSERT INTO TEMPJUGADA(fecha, usuario, tematica, pregunta, respuesta)
      VALUES (SYSTIMESTAMP, v_usuario, v_tematica, v_enunciado, v_respuesta_correcta);
    COMMIT;
END;
/
-- En este momento se habrá mostrado la pregunta.

-- (2) Solicitar al usuario la respuesta (fuera del bloque PL/SQL)
ACCEPT eleccion PROMPT 'Ingrese su respuesta (A, B, C, D): '

-- (3) Bloque 2: Validar la respuesta y registrarla en JUGADA
DECLARE
    v_enunciado         TEMPJUGADA.pregunta%TYPE;
    v_respuesta_correcta TEMPJUGADA.respuesta%TYPE;
    v_usuario           TEMPJUGADA.usuario%TYPE;
    v_tematica          TEMPJUGADA.tematica%TYPE;
    v_eleccion          VARCHAR2(30) := '&eleccion';
    v_resultado         VARCHAR2(10);
BEGIN
    -- Recuperar la última pregunta almacenada en TEMPJUGADA
    SELECT usuario, tematica, pregunta, respuesta
      INTO v_usuario, v_tematica, v_enunciado, v_respuesta_correcta
    FROM ( SELECT usuario, tematica, pregunta, respuesta FROM TEMPJUGADA ORDER BY fecha DESC )
    WHERE ROWNUM = 1;

    -- Mostrar la pregunta nuevamente
    DBMS_OUTPUT.PUT_LINE('-------------------------------------');
    DBMS_OUTPUT.PUT_LINE('Pregunta que estás respondiendo: ' || v_enunciado);
    DBMS_OUTPUT.PUT_LINE('-------------------------------------');

    -- Validar la respuesta
    IF UPPER(v_eleccion) = UPPER(v_respuesta_correcta) THEN
        v_resultado := 'ACIERTO';
        DBMS_OUTPUT.PUT_LINE('¡Respuesta correcta!');
    ELSE
        v_resultado := 'FALLO';
        DBMS_OUTPUT.PUT_LINE('Respuesta incorrecta. La respuesta correcta es: ' || v_respuesta_correcta);
    END IF;

    -- Registrar la jugada en la tabla JUGADA
    INSERT INTO JUGADA(fecha, usuario, tematica, pregunta, eleccion, respuesta, resultado)
      VALUES (SYSTIMESTAMP, v_usuario, v_tematica, v_enunciado, v_eleccion, v_respuesta_correcta, v_resultado);
    COMMIT;
END;
/

--ESTADISTICAS
 
SET SERVEROUTPUT ON;
DECLARE
    v_usuario    VARCHAR2(25) := '&usuario_estadisticas';
    v_total      NUMBER;
    v_aciertos   NUMBER;
    v_fallos     NUMBER;
BEGIN
    -- Calcular el total de jugadas y el número de aciertos y fallos para el usuario dado
    SELECT COUNT(*) INTO v_total FROM JUGADA WHERE usuario = v_usuario;
    SELECT COUNT(*) INTO v_aciertos FROM JUGADA WHERE usuario = v_usuario AND resultado = 'ACIERTO';
    SELECT COUNT(*) INTO v_fallos FROM JUGADA WHERE usuario = v_usuario AND resultado = 'FALLO';
    DBMS_OUTPUT.PUT_LINE('-------------------------------------');
    DBMS_OUTPUT.PUT_LINE('Estadísticas para el usuario: ' || v_usuario);
    DBMS_OUTPUT.PUT_LINE('-------------------------------------');
    -- Mostrar las jugadas registradas
    FOR rec IN (
        SELECT fecha, tematica, pregunta, eleccion, respuesta, resultado 
        FROM JUGADA 
        WHERE usuario = v_usuario
        ORDER BY fecha
    ) LOOP
         DBMS_OUTPUT.PUT_LINE('Fecha: '   || rec.fecha ||
                              ' | Temática: ' || rec.tematica ||
                              ' | Pregunta: ' || rec.pregunta ||
                              ' | Elección: ' || rec.eleccion ||
                              ' | Respuesta: ' || rec.respuesta ||
                              ' | Resultado: ' || rec.resultado);
    END LOOP;
    -- Mostrar porcentajes (se controla la división para evitar división por cero)
    IF v_total > 0 THEN
         DBMS_OUTPUT.PUT_LINE('Porcentaje de aciertos: ' || TO_CHAR((v_aciertos/v_total)*100, 'FM990.00') || '%');
         DBMS_OUTPUT.PUT_LINE('Porcentaje de fallos: '   || TO_CHAR((v_fallos/v_total)*100, 'FM990.00') || '%');
    ELSE
         DBMS_OUTPUT.PUT_LINE('No existen jugadas registradas para ' || v_usuario);
    END IF;
    DBMS_OUTPUT.PUT_LINE('-------------------------------------');
END;
/
