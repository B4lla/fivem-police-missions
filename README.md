# qb-servicejobs

Recurso de misiones anti-AFK para QB-Core con dos terminales NPC:

- NPC de policia (`police`) en MRPD.
- NPC de EMS (`ambulance`) en Pillbox.

Incluye UI NUI moderna (clip-path + typewriter), aceptacion/rechazo de mision, 12 misiones distintas (6 por job), y pago en efectivo al completar.

## Modo cooperativo

- Antes de iniciar, el lider puede invitar desde la UI a jugadores cercanos del mismo job.
- Tamano maximo del equipo configurable en `Config.Team.MaxMembers`.
- Los invitados reciben popup para aceptar o rechazar.
- La mision arranca sincronizada para el equipo.
- El lider ejecuta los objetivos y los miembros en apoyo deben mantenerse activos y cerca.
- Cada miembro cobra de forma individual solo si cumple anti-farm:
   - Participacion minima en checkpoints (`Config.Team.MinCheckpointsForPayout`).
   - Distancia maxima al lider al cierre (`Config.Team.MaxPayoutDistanceFromLeader`).

## Dependencias

- `qb-core`
- `qb-target`

## Instalacion

1. Copia la carpeta `qb-servicejobs` dentro de tu carpeta de recursos.
2. Asegura el recurso en tu server.cfg:
   - `ensure qb-servicejobs`
3. Reinicia el servidor o el recurso.

## Comportamiento

- Solo puede abrir cada terminal el job correspondiente.
- Una sola mision activa por jugador.
- Cooldown tras cada completada (`Config.CooldownSeconds`).
- Validacion de integridad en servidor antes de pagar.
- Pago en `cash` entre `$120-$250` con multiplicador por dificultad.
- En equipos, el pago del miembro aplica `Config.Team.MemberPayoutMultiplier`.

## Comando

- `/cancelservicio` para cancelar la mision activa.

## Configuracion rapida

Edita:

- `shared/config.lua` para jobs, pagos, cooldown, timeout y coordenadas.
- `shared/missions.lua` para textos y catalogo de misiones.
- `shared/config.lua > Config.Team` para limites, rango de invitacion y validaciones anti-farm.

## Estructura

- `client/npc.lua`: spawn de NPCs e interaccion qb-target.
- `client/ui.lua`: puente cliente <-> NUI.
- `client/mission_core.lua`: utilidades comunes, estados y cleanup.
- `client/missions_police.lua`: misiones de policia.
- `client/missions_ems.lua`: misiones EMS.
- `server/main.lua`: validaciones, cooldown y pago.
- `html/*`: interfaz.
