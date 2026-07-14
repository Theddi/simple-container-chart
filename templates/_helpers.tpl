{{- define "simple-container.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{- define "simple-container.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end }}

{{- define "simple-container.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{ include "simple-container.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "simple-container.selectorLabels" -}}
app.kubernetes.io/name: {{ include "simple-container.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "simple-container.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "simple-container.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end }}

{{/*
Assemble the full image reference from registry / repository / image : tag.
Empty registry or repository segments are skipped, so this works for
docker.io/library images, ghcr.io/org/app, registry.k8s.io/proj/app, etc.
*/}}
{{- define "simple-container.image" -}}
{{- $tag := .Values.image.tag | default .Chart.AppVersion | toString -}}
{{- $parts := list -}}
{{- with .Values.image.registry }}{{- $parts = append $parts . }}{{- end -}}
{{- with .Values.image.repository }}{{- $parts = append $parts . }}{{- end -}}
{{- $parts = append $parts (required "image.image (the image name) is required" .Values.image.image) -}}
{{- printf "%s:%s" (join "/" $parts) $tag -}}
{{- end }}
