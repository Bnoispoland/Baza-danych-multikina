CREATE TABLE Bilety(
    Kod NVARCHAR (8) NOT NULL ,
    "Kod Filmu" NVARCHAR (12) NOT NULL ,
    Data   DATETIME ,
    Sala   SMALLINT NOT NULL ,
    Klient SMALLINT ,
    "Zapłacono (PLN)" MONEY
)
ON "default"
GO
ALTER TABLE Bilety ADD CONSTRAINT Bilety_PK PRIMARY KEY CLUSTERED (Kod)
WITH
  (
    ALLOW_PAGE_LOCKS = ON ,
    ALLOW_ROW_LOCKS  = ON
  )
  ON "default"

GO

CREATE TABLE Członkostwo(
    NR SMALLINT NOT NULL IDENTITY NOT FOR REPLICATION ,
    Imię NVARCHAR (15) ,
    Nazwisko NVARCHAR (15) ,
    "Data Założenia Konta" DATETIME ,
    Rabat                  SMALLINT
  )
  ON "default"
GO
ALTER TABLE Członkostwo ADD CONSTRAINT Członkostwo_PK PRIMARY KEY CLUSTERED (NR
)
WITH
  (
    ALLOW_PAGE_LOCKS = ON ,
    ALLOW_ROW_LOCKS  = ON
  )
  ON "default"

GO

CREATE TABLE Filmy(
    Kod NVARCHAR (12) NOT NULL ,
    Nazwa NVARCHAR (30) ,
    Czas TIME ,
    Dubbing NVARCHAR (3) ,
    Napisy NVARCHAR (3) ,
    "3D" NVARCHAR (3) ,
    Kraj NVARCHAR (15) ,
    Producent SMALLINT NOT NULL
  )
  ON "default"
GO
ALTER TABLE Filmy ADD CONSTRAINT Filmy_PK PRIMARY KEY CLUSTERED (Kod)
WITH
  (
    ALLOW_PAGE_LOCKS = ON ,
    ALLOW_ROW_LOCKS  = ON
  )
  ON "default"

GO

CREATE TABLE Gastronomia(
    Kod NVARCHAR (12) NOT NULL ,
    Nazwa NVARCHAR (30) ,
    "Cena (PLN)" MONEY ,
    Rozmiar NVARCHAR (15) ,
    Producent SMALLINT NOT NULL
  )
  ON "default"
GO
ALTER TABLE Gastronomia ADD CONSTRAINT Gastronomia_PK PRIMARY KEY CLUSTERED (
Kod)
WITH
  (
    ALLOW_PAGE_LOCKS = ON ,
    ALLOW_ROW_LOCKS  = ON
  )
  ON "default"
GO

CREATE TABLE "Godziny Pracy"(
    ID SMALLINT NOT NULL ,
    Poniedziałek TIME ,
    Wtorek TIME ,
    Środa TIME ,
    Czwartek TIME ,
    Piątek TIME ,
    Sobota TIME ,
    Niedziela TIME ,
    Urlop NVARCHAR (3)
  )
  ON "default"
GO
ALTER TABLE "Godziny Pracy" ADD CONSTRAINT "Godziny Pracy_PK" PRIMARY KEY
CLUSTERED (ID)
WITH
  (
    ALLOW_PAGE_LOCKS = ON ,
    ALLOW_ROW_LOCKS  = ON
  )
  ON "default"

GO

CREATE TABLE Kasy(
    NR   SMALLINT ,
    Data DATE ,
    Stan NVARCHAR (10) ,
    "Dochód (PLN)" MONEY ,
    Obsługujący SMALLINT
  )
  ON "default"

GO

CREATE TABLE Pracownicy(
    ID SMALLINT NOT NULL IDENTITY NOT FOR REPLICATION ,
    PESEL BIGINT NOT NULL ,
    Stanowisko NVARCHAR (15) ,
    Kasa SMALLINT
  )
  ON "default"
GO
ALTER TABLE Pracownicy ADD CONSTRAINT Pracownicy_PK PRIMARY KEY CLUSTERED (ID)
WITH
  (
    ALLOW_PAGE_LOCKS = ON ,
    ALLOW_ROW_LOCKS  = ON
  )
  ON "default"
GO
ALTER TABLE Pracownicy ADD CONSTRAINT Pracownicy__UN UNIQUE NONCLUSTERED (PESEL
)
ON "default"

GO

CREATE TABLE Producenci(
    Numer SMALLINT NOT NULL IDENTITY NOT FOR REPLICATION ,
    Nazwa NVARCHAR (30) ,
    Kraj NVARCHAR (15) ,
    Typ NVARCHAR (20) ,
    "Ilość towaru" SMALLINT
  )
  ON "default"
GO
ALTER TABLE Producenci ADD CONSTRAINT Producenci_PK PRIMARY KEY CLUSTERED (
Numer)
WITH
  (
    ALLOW_PAGE_LOCKS = ON ,
    ALLOW_ROW_LOCKS  = ON
  )
  ON "default"
GO
ALTER TABLE Producenci ADD CONSTRAINT Producenci__UN UNIQUE NONCLUSTERED (Nazwa
)
ON "default"

GO

CREATE TABLE "Rejestr Pracowników"(
    Imię NVARCHAR (15) ,
    Nazwisko NVARCHAR (15) ,
    "Data Urodzenia"    DATE ,
    "Data Zatrudnienia" DATE ,
    PESEL BIGINT NOT NULL ,
    Adres NVARCHAR (30) ,
    Stanowisko NVARCHAR (15) ,
    "Data Zwolnienia" DATE
  )
  ON "default"
GO
ALTER TABLE "Rejestr Pracowników" ADD CONSTRAINT Pracownicyv1_PK PRIMARY KEY
CLUSTERED (PESEL)
WITH
  (
    ALLOW_PAGE_LOCKS = ON ,
    ALLOW_ROW_LOCKS  = ON
  )
  ON "default"

GO

CREATE TABLE Sale(
    Nr SMALLINT NOT NULL ,
    Typ NVARCHAR (10) ,
    Stan NVARCHAR (8) ,
    Miejsca         SMALLINT ,
    "Wolne miejsca" SMALLINT ,
    Obsługujący     SMALLINT
  )
  ON "default"
GO
ALTER TABLE Sale ADD CONSTRAINT Sale_PK PRIMARY KEY CLUSTERED (Nr)
WITH
  (
    ALLOW_PAGE_LOCKS = ON ,
    ALLOW_ROW_LOCKS  = ON
  )
  ON "default"

GO

CREATE TABLE Seansy(
    Sala SMALLINT NOT NULL ,
    Kod NVARCHAR (12) NOT NULL ,
    Poniedziałek TIME ,
    Wtorek TIME ,
    Środa TIME ,
    Czwartek TIME ,
    Piątek TIME ,
    Sobota TIME ,
    Niedziela TIME
  )
  ON "default"
GO
ALTER TABLE Seansy ADD CONSTRAINT Seansy2__UN UNIQUE NONCLUSTERED (Kod)
ON "default"

GO

CREATE TABLE Sprzedaż(
    Kod NVARCHAR (12) NOT NULL ,
    Kategoria NVARCHAR (10) ,
    "Cena (PLN)" MONEY ,
    Pracownik SMALLINT NOT NULL ,
    Data      DATETIME ,
    Klient    SMALLINT
  )
  ON "default"

GO

CREATE TABLE Towar(
    "Kod Filmu" NVARCHAR (12) ,
    "Kod Gastro" NVARCHAR (12) ,
    Kategoria NVARCHAR (11) ,
    "Cena (PLN)" MONEY ,
    Dostępność NVARCHAR (15) ,
    Producent SMALLINT NOT NULL
  )
  ON "default"
GO
ALTER TABLE Towar ADD CONSTRAINT Towar__UNv2 UNIQUE NONCLUSTERED ("Kod Filmu",
"Kod Gastro")
ON "default"

GO

ALTER TABLE Bilety
ADD CONSTRAINT Bilety_Członkostwo_FK FOREIGN KEY(Klient) REFERENCES Członkostwo(NR)
ON
DELETE
  NO ACTION ON
UPDATE NO ACTION
GO

ALTER TABLE Bilety
ADD CONSTRAINT Bilety_Filmy_FK FOREIGN KEY( "Kod Filmu" ) REFERENCES Filmy(Kod)
ON
DELETE
  NO ACTION ON
UPDATE NO ACTION
GO

ALTER TABLE Bilety
ADD CONSTRAINT Bilety_Sale_FK FOREIGN KEY(Sala) REFERENCES Sale(Nr)
ON
DELETE
  NO ACTION ON
UPDATE NO ACTION
GO

ALTER TABLE Filmy
ADD CONSTRAINT Filmy_Producenci_FK FOREIGN KEY(Producent) REFERENCES Producenci(Numer)
ON
DELETE
  NO ACTION ON
UPDATE NO ACTION
GO

ALTER TABLE Gastronomia
ADD CONSTRAINT Gastronomia_Producenci_FK FOREIGN KEY(Producent) REFERENCES Producenci(Numer)
ON
DELETE
  NO ACTION ON
UPDATE NO ACTION
GO

ALTER TABLE "Godziny Pracy"
ADD CONSTRAINT "Godziny Pracy_Pracownicy_FK" FOREIGN KEY(ID) REFERENCES Pracownicy(ID)
ON
DELETE
  NO ACTION ON
UPDATE NO ACTION
GO

ALTER TABLE Kasy
ADD CONSTRAINT Kasy_Pracownicy_FKv1 FOREIGN KEY(Obsługujący) REFERENCES Pracownicy(ID)
ON
DELETE
  NO ACTION ON
UPDATE NO ACTION
GO

ALTER TABLE Pracownicy
ADD CONSTRAINT "Pracownicy_Rejestr Pracowników_FK" FOREIGN KEY(PESEL) REFERENCES "Rejestr Pracowników"(PESEL)
ON
DELETE
  NO ACTION ON
UPDATE NO ACTION
GO

ALTER TABLE Sale
ADD CONSTRAINT Sale_Pracownicy_FK FOREIGN KEY(Obsługujący) REFERENCES Pracownicy(ID)
ON
DELETE
  NO ACTION ON
UPDATE NO ACTION
GO

ALTER TABLE Seansy
ADD CONSTRAINT Seansy2_Filmy_FK FOREIGN KEY(Kod) REFERENCES Filmy(Kod)
ON
DELETE
  NO ACTION ON
UPDATE NO ACTION
GO

ALTER TABLE Seansy
ADD CONSTRAINT Seansy2_Sale_FK FOREIGN KEY(Sala) REFERENCES Sale(Nr)
ON
DELETE
  NO ACTION ON
UPDATE NO ACTION
GO

ALTER TABLE Sprzedaż
ADD CONSTRAINT Sprzedaż_Członkostwo_FK FOREIGN KEY(Klient) REFERENCES Członkostwo(NR)
ON
DELETE
  NO ACTION ON
UPDATE NO ACTION
GO

ALTER TABLE Sprzedaż
ADD CONSTRAINT Sprzedaż_Pracownicy_FK FOREIGN KEY(Pracownik) REFERENCES Pracownicy(ID)
ON
DELETE
  NO ACTION ON
UPDATE NO ACTION
GO

ALTER TABLE Towar
ADD CONSTRAINT Towar_Producenci_FK FOREIGN KEY(Producent) REFERENCES Producenci(Numer)
ON
DELETE
  NO ACTION ON
UPDATE NO ACTION
GO