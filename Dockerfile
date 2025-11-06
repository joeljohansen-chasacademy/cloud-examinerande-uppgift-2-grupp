
# När Docker bygger en image används .dockerignore för att undvika att kopiera in känsliga filer (som .env) in i imagen.
# Next.js behöver NEXT_PUBLIC_* variablerna vid build-time för att baka in dem i JavaScript-bundlen som skickas till webbläsaren.

# Utan tillgång till .env-filen i Docker-containern under npm run build finns inga värden att baka in. 

# Med en multi-stage build (lösningen nedan) passerar vi värdena som build-arguments (ARG) istället för att kopiera in .env-filen. Värdena används i build-staget för att
# kompilera appen, men det slutgiltiga production-staget innehåller bara den färdiga .next-mappen - inte build-argumenten.

# När ni bvygger sen behöver ni skicka in build-argarna som ni får från supabase.
# Detta finns då tillgängligt i build-processen och bakas ju sen in i koden via next build.
# Men eftersom vi gör en multi-stage build så finns de inte med i production stage.
# Detta är helt ok eftersom supabase nycklar är byggda för att kunna användas i klienten (så länge man har RLS-policies)
# Men gör inte såhär för några nycklar som ska vara hemliga!
#docker build \
#--build-arg NEXT_PUBLIC_SUPABASE_URL=<eran-supabase-url> \
#--build-arg NEXT_PUBLIC_SUPABASE_ANON_KEY=<eran-anon-key> \
#-t dagboks-appen .

# Build stage
FROM node:20-alpine AS builder

WORKDIR /app

# Kopiera package files
COPY package*.json ./

# Installera dependencies
RUN npm install

# Kopiera all kod
COPY . .

# Deklarera build arguments för Supabase
ARG NEXT_PUBLIC_SUPABASE_URL
ARG NEXT_PUBLIC_SUPABASE_ANON_KEY

# Sätt dem som miljövariabler för build-processen
ENV NEXT_PUBLIC_SUPABASE_URL=$NEXT_PUBLIC_SUPABASE_URL
ENV NEXT_PUBLIC_SUPABASE_ANON_KEY=$NEXT_PUBLIC_SUPABASE_ANON_KEY

# Bygg applikationen
RUN npm run build

# Production stage
FROM node:20-alpine AS runner

WORKDIR /app

ENV NODE_ENV=production

# Kopiera package files och installera endast production dependencies
COPY package*.json ./
RUN npm ci --only=production

# Kopiera byggda filer från builder stage
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/public ./public

# Exponera port
EXPOSE 3000

# Starta applikationen
CMD ["npm", "start"]


