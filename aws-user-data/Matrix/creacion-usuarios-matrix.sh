###### Creacion de usuarios dentro de matrix
# Bucle infinito que se detiene si el usuario responde "no"
while true; do
  # Aqui puedes colocar el comando que quieres ejecutar
  echo "Creacion de usuarios matrix"
  register_new_matrix_user -c /etc/matrix-synapse/homeserver.yaml https://marcosmatrix.duckdns.org
  # Pregunta al usuario si desea continuar
  read -p "¿Quieres seguir ejecutando el comando? (si/no): " respuesta

  # Evaluamos la respuesta
  if [ "$respuesta" == "no" ]; then
    echo "Saliendo del script..."
    break  # Sale del bucle y termina el script
  elif [ "$respuesta" == "si" ]; then
    echo "Repitiendo el comando..."
    clear
  else
    echo "Respuesta no valida. Por favor, responde 'si' o 'no'."
  fi
done
