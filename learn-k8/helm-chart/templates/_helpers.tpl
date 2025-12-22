{{- define "my-app.name" -}}
{{- default "my-app" .Values.nameOverride -}}
{{- end -}}

{{- define "my-app.fullname" -}}
{{- printf "%s-%s" .Release.Name (include "my-app.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
