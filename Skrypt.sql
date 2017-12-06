CREATE PROCEDURE GET_ERROR
AS
	SELECT
		ERROR_NUMBER() AS ErrorNumber,
		ERROR_SEVERITY() AS ErrorSeverity,
		ERROR_STATE() AS ErrorState,
		ERROR_PROCEDURE() AS ErrorProcedure,
		ERROR_LINE() AS ErrorLine,
		ERROR_MESSAGE() AS ErrorMessage
GO

CREATE VIEW MAKE_PESEL
AS SELECT 100000000 + CONVERT(BIGINT, (999999999-100000000+1)*RAND()) AS P
GO

CREATE FUNCTION dbo.GENERUJ_PESEL ()
RETURNS BIGINT
AS
BEGIN
	DECLARE @P BIGINT
	SET @P = (SELECT P FROM MAKE_PESEL) 
	RETURN @P
END
GO

CREATE PROCEDURE KASY_INIT
AS
	INSERT Kasy VALUES
	(1, GETDATE(), 'Nieaktywna', 0, NULL),
	(2, GETDATE(), 'Nieaktywna', 0, NULL),
	(3, GETDATE(), 'Nieaktywna', 0, NULL)
GO


CREATE PROCEDURE ADD_RP ( @Imię NVARCHAR(15), @Nazw NVARCHAR(15), @DU DATE, @ADR NVARCHAR(30), @ST NVARCHAR (15))
AS
	BEGIN TRY
		IF EXISTS ( SELECT * FROM Pracownicy WHERE Stanowisko = 'BOSS') AND @ST = 'BOSS'
			RAISERROR ('Moze byc tylko 1 aktywny BOSS', 16, 1)
		ELSE
			IF ( SELECT COUNT(*) FROM Pracownicy ) > 21
				RAISERROR ('Maksymalna liczba aktywnych pracownikow - 21', 16, 1)
			ELSE
				INSERT INTO [Rejestr Pracowników] VALUES (@Imię, @Nazw, @DU, GETDATE(), dbo.GENERUJ_PESEL(), @ADR, @ST, NULL)
	END TRY
	BEGIN CATCH
		EXECUTE GET_ERROR
	END CATCH
GO

CREATE PROCEDURE DEL_PR (@P BIGINT)
AS
	BEGIN TRY
		IF NOT EXISTS ( SELECT * FROM Pracownicy WHERE PESEL = @P )
			RAISERROR ('Podany pracownik nie istnieje', 16, 1)
		ELSE
		BEGIN
			DECLARE @ID SMALLINT
			SELECT @ID = ID FROM Pracownicy WHERE PESEL = @P

			UPDATE [Rejestr Pracowników] SET [Data Zwolnienia] = GETDATE() WHERE PESEL = @P
			UPDATE Sale SET Obsługujący = NULL WHERE Obsługujący = @ID
			UPDATE Kasy SET Obsługujący = NULL WHERE Obsługujący = @ID
			DELETE FROM Sprzedaż WHERE Pracownik = @ID
			DELETE FROM [Godziny Pracy] WHERE ID = @ID
			DELETE FROM Pracownicy WHERE Pracownicy.PESEL = @P
		END
	END TRY
	BEGIN CATCH
		EXECUTE GET_ERROR
	END CATCH
GO

CREATE TRIGGER NEW_RP ON [Rejestr Pracowników] AFTER INSERT
AS
BEGIN
	SET NOCOUNT ON
	DECLARE @P BIGINT
	SELECT @P = PESEL FROM INSERTED

	INSERT INTO Pracownicy SELECT @P, Stanowisko, NULL FROM INSERTED
	INSERT INTO [Godziny Pracy] SELECT ID, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'NIE' 
								FROM Pracownicy WHERE Pracownicy.PESEL = @P
	
	IF ( SELECT COUNT(*) FROM Pracownicy ) = 15
		EXEC KASY_INIT
END

GO

CREATE TRIGGER CHANGE_RP ON [Rejestr Pracowników] AFTER UPDATE
AS
BEGIN
	DECLARE @P BIGINT
	SELECT @P = PESEL FROM INSERTED

	IF ( SELECT [Data Zwolnienia] FROM INSERTED ) IS NOT NULL
		EXEC DEL_PR @P
	ELSE
	BEGIN
		DECLARE @S NVARCHAR(15), @S2 NVARCHAR(15)
		SELECT @S = Stanowisko FROM INSERTED
		SELECT @S2 = Stanowisko FROM DELETED 

		IF @S != @S2
		BEGIN
			UPDATE Pracownicy SET Stanowisko = @S WHERE PESEL = @P
			UPDATE Pracownicy SET Stanowisko = @S2 WHERE PESEL != @P AND Stanowisko = @S
		END
	END
END
GO

CREATE TRIGGER NEW_GP ON [Godziny Pracy] FOR INSERT
AS
BEGIN
	SET NOCOUNT ON
	DECLARE @ID SMALLINT 
	SELECT @ID = ID FROM INSERTED

	IF ( SELECT Stanowisko FROM Pracownicy WHERE ID = @ID ) != 'BOSS'
	BEGIN
		DECLARE @T INT, @TP INT
		SET @T = ( SELECT COUNT(*) FROM [Godziny Pracy] WHERE Poniedziałek IS NOT NULL )
		SET @TP = ( SELECT COUNT(*) FROM [Godziny Pracy] WHERE Piątek IS NOT NULL )

		IF @T = @TP
		BEGIN
			IF ( SELECT COUNT(*) % 2 FROM [Godziny Pracy] WHERE Poniedziałek IS NOT NULL) != 0 AND
			   ( SELECT COUNT(*) FROM [Godziny Pracy] WHERE Poniedziałek = '14:00:00' ) < 5
				UPDATE [Godziny Pracy] 
				SET Poniedziałek = '14:00:00', Wtorek = '14:00:00', Środa = '14:00:00', Czwartek = '14:00:00'
				WHERE [Godziny Pracy].ID = @ID
			ELSE
			BEGIN
				UPDATE [Godziny Pracy] 
				SET Poniedziałek = '08:00:00', Wtorek = '08:00:00', Środa = '08:00:00', Czwartek = '08:00:00'
				WHERE [Godziny Pracy].ID = @ID
			END
		END
		ELSE
		BEGIN
			IF ( SELECT COUNT(*) % 2 FROM [Godziny Pracy] WHERE Piątek IS NOT NULL) != 0 AND
			   ( SELECT COUNT(*) FROM [Godziny Pracy] WHERE Piątek = '14:00:00' ) < 5
				UPDATE [Godziny Pracy] 
				SET Piątek = '14:00:00', Sobota = '14:00:00', Niedziela = '14:00:00'
				WHERE [Godziny Pracy].ID = @ID
			ELSE
			BEGIN
				UPDATE [Godziny Pracy] 
				SET Piątek = '08:00:00', Sobota = '08:00:00', Niedziela = '08:00:00'
				WHERE [Godziny Pracy].ID = @ID
			END
		END
	END
END
GO

CREATE FUNCTION dbo.GET_PR()
RETURNS SMALLINT
AS
BEGIN
	DECLARE @Time TIME(7), @Day NVARCHAR(12), @ID SMALLINT
	SET @Day = DATENAME(dw,GETDATE())
	SET @Time = CAST(GETDATE() AS TIME(7))
	SET @ID = (SELECT TOP 1 Pracownicy.ID FROM ( SELECT ID FROM [Godziny Pracy] GP 
					WHERE ( ((@Day = 'Monday' OR @Day = 'Tuesday' OR @Day = 'Wednesday' OR @Day = 'Thursday')
							AND GP.Poniedziałek IS NOT NULL AND ((@Time BETWEEN GP.Poniedziałek AND '14:00:00') OR 
							(@Time BETWEEN GP.Poniedziałek AND '20:00:00' AND GP.Poniedziałek >= '14:00:00'))) OR
							((@Day = 'Friday' OR @Day = 'Saturday' OR @Day = 'Sunday') 
							AND GP.Piątek IS NOT NULL AND ((@Time BETWEEN GP.Piątek AND '14:00:00') OR 
						    (@Time BETWEEN GP.Piątek AND '20:00:00' AND GP.Piątek >= '14:00:00'))))
				  ) AS L JOIN Pracownicy ON L.ID = Pracownicy.ID AND Pracownicy.Kasa IS NULL)
	RETURN @ID
END
GO

CREATE TRIGGER KASY_FILL ON Kasy FOR INSERT
AS
BEGIN
	SET NOCOUNT ON
	DECLARE @ID SMALLINT, @NR SMALLINT
	SET @NR = 1
	WHILE ( @NR < 4 )
	BEGIN
		SET @ID = dbo.GET_PR()

		IF @ID IS NULL 
			SET @NR = 5
		ELSE
		BEGIN
			UPDATE Kasy SET Obsługujący = @ID, Stan = 'Aktywna' WHERE NR = @NR AND CONVERT(DATE,GETDATE()) = CONVERT(DATE,Data)
			UPDATE Pracownicy SET Kasa = @NR WHERE ID = @ID
		END
		SET @NR = @NR + 1
	END
END
GO

CREATE VIEW Losowanie
AS
SELECT CHAR(RAND()*26+65) AS Element
GO

CREATE FUNCTION dbo.GENERUJ_KOD (@Dlugosc BIGINT)
RETURNS NVARCHAR(20)
AS
BEGIN
	DECLARE @Kod NVARCHAR(20), @COUNT BIGINT
	SET @COUNT = @Dlugosc
	WHILE ( @COUNT > 0 )
	BEGIN
	  SET @Kod = (SELECT CONCAT ( @Kod, (SELECT Element FROM Losowanie)))
	  SET @COUNT = @COUNT - 1
	END
	RETURN @Kod
END
GO

CREATE FUNCTION dbo.OBLICZ_RABAT ( @NR SMALLINT )
RETURNS SMALLINT
AS
BEGIN
	DECLARE @R SMALLINT
	SELECT @R = SUM([Zapłacono (PLN)])/(10-COUNT (*))
	FROM Bilety WHERE Klient = @NR
	RETURN @R
END
GO

CREATE PROCEDURE SALE_INIT
AS
	DECLARE @Count SMALLINT
	SET @Count = 1
	WHILE ( @Count < 11 )
	BEGIN
		IF @Count < 6
			INSERT Sale VALUES (@Count,'Zwykla','Wolna', 10+(@Count*5), 10+(@Count*5), NULL)
		ELSE
			INSERT Sale VALUES (@Count,'3D','Wolna', (@Count*5)-10, (@Count*5)-10, NULL)
		SET @Count = @Count+1
	END
GO

CREATE PROCEDURE ADD_PRODUCENT (@Nazwa NVARCHAR(30), @Kraj NVARCHAR(15), @Typ NVARCHAR(20))
AS
BEGIN
	BEGIN TRY
		IF EXISTS ( SELECT * FROM Producenci WHERE Nazwa = @Nazwa)
			RAISERROR ('Podany producent został dodany wcześniej', 16, 1)
		ELSE
		IF @Typ != 'Filmy' AND @Typ != 'Gastronomia'
			RAISERROR ('Dostepne typy producentow: Filmy oraz Gastronomia', 16, 1)
		ELSE
		INSERT Producenci VALUES (@Nazwa, @Kraj, @Typ, 0)
	END TRY
	BEGIN CATCH
		EXECUTE GET_ERROR
	END CATCH
END
GO

CREATE PROCEDURE ADD_GASTRO (@Nazwa NVARCHAR(30), @Cena MONEY, @Rozmiar NVARCHAR(15), @Prod SMALLINT)
AS
BEGIN
	BEGIN TRY
		IF EXISTS ( SELECT * FROM Gastronomia WHERE Nazwa = @Nazwa AND Rozmiar = @Rozmiar) 
			RAISERROR ('Podany produkt został dodany wcześniej', 16, 1)
		ELSE
		BEGIN
			IF NOT EXISTS ( SELECT * FROM Producenci WHERE Numer = @Prod )
				RAISERROR ('Podany producent nie istnieje', 16, 1)
			ELSE
			IF EXISTS ( SELECT * FROM Producenci WHERE Numer = @Prod AND Typ != 'Gastronomia')
				RAISERROR ('Podany producent sprzedaje wylacznie filmy', 16, 1)
			ELSE
				INSERT Gastronomia VALUES (dbo.GENERUJ_KOD(12), @Nazwa, @Cena, @Rozmiar, @Prod)
		END
	END TRY
	BEGIN CATCH
		EXECUTE GET_ERROR
	END CATCH
END
GO

CREATE TRIGGER NEW_GASTRO ON Gastronomia AFTER INSERT, UPDATE, DELETE
AS
BEGIN
	DECLARE @Kod NVARCHAR (12), @Cena MONEY, @Producent SMALLINT

	IF NOT EXISTS ( SELECT * FROM DELETED )
	BEGIN
		SELECT @Kod = Kod, @Cena = [Cena (PLN)], @Producent = Producent FROM INSERTED
		
		UPDATE Producenci SET [Ilość towaru] = [Ilość towaru]+1 WHERE Numer = @Producent
		INSERT Towar VALUES ( NULL, @Kod, 'Gastronomia', @Cena, '1000', @Producent )
	END
	ELSE
	IF NOT EXISTS ( SELECT * FROM INSERTED)
	BEGIN
		SELECT @Kod = Kod, @Producent = Producent FROM DELETED
		
		DELETE FROM Towar WHERE Towar.[Kod Gastro] = @Kod
		UPDATE Producenci SET [Ilość towaru] = [Ilość towaru]-1 WHERE Producenci.Numer = @Producent
	END
	ELSE
	BEGIN
		ROLLBACK
		RAISERROR ('Nie mozna zmieniac danych', 16, 1)
	END
END
GO

CREATE PROCEDURE ADD_FILM (@Nazwa NVARCHAR(30), @Czas TIME, @Dub NVARCHAR(3), @Napisy NVARCHAR(3), @3D NVARCHAR (3), @Kraj NVARCHAR(15), @Producent SMALLINT)
AS
BEGIN
	BEGIN TRY
		IF EXISTS ( SELECT * FROM Filmy WHERE Nazwa = @Nazwa AND Dubbing = @Dub AND Napisy = @Napisy AND [3D] = @3D) 
			RAISERROR ('Podany film został dodany wcześniej', 16, 1)
		ELSE
		BEGIN
			IF NOT EXISTS ( SELECT * FROM Producenci WHERE Numer = @Producent )
				RAISERROR ('Podany producent nie istnieje', 16, 1)
			ELSE
			IF EXISTS ( SELECT * FROM Producenci WHERE Numer = @Producent AND Typ != 'Filmy')
				RAISERROR ('Podany producent sprzedaje wylacznie produkty gastronomiczne', 16, 1)
			ELSE 
			IF (@Dub != 'Tak' AND @Dub != 'Nie') OR (@3D != 'Tak' AND @3D != 'Nie') OR ( @Napisy != 'Tak' AND @Napisy != 'Nie')
				RAISERROR ('Kolumny Dubbing, Napisy oraz 3D moga przyjmowac wartosci wylacznie "Tak" albo "Nie"', 16, 1)	
			ELSE
				INSERT Filmy VALUES (dbo.GENERUJ_KOD(12), @Nazwa, @Czas, @Dub, @Napisy, @3D, @Kraj, @Producent)
		END
	END TRY
	BEGIN CATCH
		EXECUTE GET_ERROR
	END CATCH
END
GO

CREATE TRIGGER DEL_FILM ON Filmy INSTEAD OF DELETE
AS
BEGIN
		DECLARE @Kod NVARCHAR (12), @Producent SMALLINT
		SELECT @Kod = Kod, @Producent = Producent FROM DELETED
		DELETE FROM Towar WHERE Towar.[Kod Filmu] = @Kod
		UPDATE Producenci SET [Ilość towaru] = [Ilość towaru]-1 WHERE Producenci.Numer = @Producent
		DELETE FROM Seansy WHERE Kod = @Kod
		DELETE FROM Filmy WHERE Kod = @Kod
END
GO

CREATE FUNCTION GET_CZAS (@Dlugosc TIME, @3D NVARCHAR (12))
RETURNS @tab TABLE (
	Sala SMALLINT,
	PN TIME, PIA TIME
)
AS
BEGIN
	DECLARE @C TIME, @Count SMALLINT, @C3 TIME,
		    @PN TIME, @PIA TIME

	IF @3D = 'Tak' SET @Count = 6
		ELSE SET @Count = 1
	
	WHILE ( @Count < 11 )
	BEGIN
		IF NOT EXISTS ( SELECT * FROM Seansy WHERE Sala = @Count)
			BEGIN INSERT @tab VALUES ( @Count, '08:00:00',NULL )
				  RETURN
			END
		ELSE
			BEGIN
				IF ( SELECT MAX(Piątek) FROM Seansy WHERE Sala = @Count ) IS NULL
					BEGIN INSERT @tab VALUES ( @Count, NULL,'08:00:00')
					RETURN
				END
				ELSE
				BEGIN
					SELECT @PN = MAX(Poniedziałek) FROM Seansy WHERE Sala = @Count
					SELECT @PIA = MAX(Piątek) FROM Seansy WHERE Sala = @Count
					IF (SELECT COUNT(*) FROM Seansy WHERE Sala = @Count AND Poniedziałek IS NOT NULL ) <=
					   (SELECT COUNT(*) FROM Seansy WHERE Sala = @Count AND Piątek IS NOT NULL )
					BEGIN
						SELECT @C3 = Czas FROM Seansy S JOIN Filmy F ON S.Sala = @Count AND Poniedziałek = @PN AND S.Kod = F.Kod
						SET @C = convert(TIME,dateadd(mi,DATEPART(MINUTE, @C3),dateadd(hh,DATEPART(HOUR, @C3),@PN)),114)
						SET @PN = convert(TIME,dateadd(mi,DATEPART(MINUTE, @Dlugosc),dateadd(hh,DATEPART(HOUR, @Dlugosc),@C)),114)
						IF @PN < '20:00:00'
						BEGIN INSERT @tab VALUES ( @Count,@C,NULL)
							  RETURN
						END
						ELSE SET @Count = @Count + 1
					END
					ELSE
					BEGIN
						SELECT @C3 = Czas FROM Seansy S JOIN Filmy F ON S.Sala = @Count AND Piątek = @PIA AND S.Kod = F.Kod
						SET @C = convert(TIME,dateadd(mi,DATEPART(MINUTE, @C3),dateadd(hh,DATEPART(HOUR, @C3),@PIA)),114)
						SET @PIA = convert(TIME,dateadd(mi,DATEPART(MINUTE, @Dlugosc),dateadd(hh,DATEPART(HOUR, @Dlugosc),@C)),114)
						IF @PIA < '20:00:00'
						BEGIN INSERT @tab VALUES ( @Count,NULL,@C)
							  RETURN
						END
						ELSE SET @Count = @Count + 1
					END
				END
			END
	END
	RETURN
END
GO

CREATE TRIGGER NEW_FILM ON Filmy AFTER INSERT, UPDATE
AS
BEGIN
	DECLARE @Kod NVARCHAR (12), @Czas TIME, @3D NVARCHAR (3), @Producent SMALLINT, @Cena MONEY
	SELECT @Kod = Kod, @Czas = Czas, @3D = [3D], @Producent = Producent FROM INSERTED
	SET @Cena = 20

	IF NOT EXISTS ( SELECT * FROM DELETED )
	BEGIN
		IF @Czas > '02:00:00' SET @Cena = @Cena + 5
		IF @3D = 'Tak' SET @Cena = @Cena + 10
		UPDATE Producenci SET [Ilość towaru] = [Ilość towaru]+1 WHERE Producenci.Numer = @Producent
		INSERT Towar VALUES ( @Kod, NULL, 'Filmy', @Cena, DATEADD(day,90, CONVERT(nvarchar(10), getdate(), 20)), @Producent )

		DECLARE @Sala SMALLINT, @PN TIME, @PI TIME

		SELECT @Sala = Sala, @PN = PN, @PI = PIA FROM GET_CZAS(@Czas, @3D)
		INSERT Seansy VALUES ( @Sala, @Kod, @PN, @PN, @PN, @PI, @PI, @PI, @PI)
	END
	ELSE
	BEGIN
		ROLLBACK
		RAISERROR ('Nie mozna zmieniac danych', 16, 1)
	END
END
GO

CREATE PROCEDURE ADD_MEMBER (@Imię NVARCHAR(15), @Nazwisko NVARCHAR(15))
AS
	INSERT Członkostwo VALUES (@Imię, @Nazwisko, GETDATE(), 0)
GO

CREATE FUNCTION dbo.CLOSEST_SEANS (@Kod NVARCHAR (12), @Data DATETIME)
RETURNS DATETIME
AS
BEGIN
	DECLARE @Days SMALLINT, @Date DATETIME, @PN TIME, @PI TIME
	
	SELECT @PN = Poniedziałek, @PI = Piątek
	FROM Seansy WHERE Seansy.Kod = @Kod

	SET @Days = DATEPART(dw,GETDATE())

	IF @PN IS NULL
	BEGIN
		IF @Days > 4 OR @Days = 1
			SET @Date = DATEADD(DAY, (DATEDIFF(DAY, 0, @Data) / 7) * 7 + 7, @Days-2)
		ELSE SET @Date = DATEADD(DAY, (DATEDIFF(DAY, 0, @Data) / 7) * 7 + 7, @Days+4)
	
		SET @Date = convert(DATETIME,dateadd(mi,DATEPART(MINUTE, @PI),dateadd(hh,DATEPART(HOUR, @PI),@Date)),114)
	END
	ELSE
	BEGIN
		IF @Days > 1 AND @Days < 5
			SET @Date = DATEADD(DAY, (DATEDIFF(DAY, 0, @Data) / 7) * 7 + 7, @Days-2)
		ELSE
		IF @Days != 1 
			SET @Date = DATEADD(DAY, (DATEDIFF(DAY, 0, @Data) / 7) * 7 + 7, @Days+4)
		ELSE SET @Date = DATEADD(DAY, (DATEDIFF(DAY, 0, @Data) / 7) * 7 + 7, @Days+3)
	
		SET @Date = convert(DATETIME,dateadd(mi,DATEPART(MINUTE, @PN),dateadd(hh,DATEPART(HOUR, @PN),@Date)),114)
	END
	RETURN @Date
END
GO

CREATE PROCEDURE SPRZEDANE ( @Kod NVARCHAR(12),@Prac SMALLINT, @Klient SMALLINT)
AS
	BEGIN TRY
		IF NOT EXISTS ( SELECT * FROM KASY WHERE Obsługujący = @Prac ) 
			RAISERROR ( 'Podany pracownik nie obsluguje zadnej kasy', 16, 1)
		ELSE
		BEGIN
			DECLARE @Kat NVARCHAR(10), @Cen MONEY
			SET @Kat = (SELECT Kategoria FROM Towar WHERE [Kod Filmu] = @Kod OR [Kod Gastro] = @Kod)

			IF @Klient IS NOT NULL
				SET @Cen = (SELECT [Cena (PLN)]-([Cena (PLN)]/100*Rabat) FROM Towar T JOIN Członkostwo C ON (T.[Kod Filmu] = @Kod OR T.[Kod Gastro] = @Kod) AND C.NR = @Klient)
			ELSE
				SET @Cen = (SELECT [Cena (PLN)] FROM Towar T WHERE T.[Kod Filmu] = @Kod OR T.[Kod Gastro] = @Kod)
			INSERT INTO Sprzedaż VALUES (@Kod, @Kat, @Cen, @Prac, GETDATE(), @Klient)
		END
	END TRY
	BEGIN CATCH
		EXECUTE GET_ERROR
	END CATCH
GO

CREATE TRIGGER SPRZEDANE_KASA ON Sprzedaż AFTER INSERT
AS
BEGIN
	DECLARE @Cen MONEY, @Prac SMALLINT, @MB NVARCHAR(12), @Data DATETIME, @Klient SMALLINT
	SELECT @Klient = Klient, @Cen = [Cena (PLN)], @Prac = Pracownik, @MB = Kod, @Data = Data FROM INSERTED
	UPDATE Kasy SET [Dochód (PLN)] = [Dochód (PLN)] + @Cen WHERE Obsługujący = @Prac

	IF EXISTS ( SELECT * FROM Filmy WHERE Kod = @MB )
	BEGIN
		IF ( SELECT CAST(CAST(Dostępność AS NVARCHAR(11)) as datetime) FROM Towar WHERE [Kod Filmu] = @MB ) <= GETDATE()
		BEGIN
				ROLLBACK
				RAISERROR ('Aktualnie nie ma zadnych seansow na ten film', 16, 1)
				DELETE FROM Seansy WHERE Kod = @MB
				DELETE FROM Towar WHERE [Kod Filmu] = @MB
				DELETE FROM Filmy WHERE Kod = @MB
		END
		ELSE
		BEGIN
			INSERT Bilety VALUES ( dbo.GENERUJ_KOD(8), @MB, dbo.CLOSEST_SEANS (@MB, @Data), (SELECT Sala FROM Seansy WHERE Kod = @MB),
							  @Klient, @Cen)
			IF @Klient IS NOT NULL
			UPDATE Członkostwo SET Rabat = dbo.OBLICZ_RABAT(@Klient) WHERE NR = @Klient
		END
	END
	ELSE
	BEGIN
		UPDATE Towar SET Dostępność = Dostępność - 1 WHERE [Kod Gastro] = @MB
		IF (SELECT Dostępność FROM Towar WHERE [Kod Gastro] = @MB ) = 0
		BEGIN
			DELETE FROM Towar WHERE [Kod Gastro] = @MB
			DELETE FROM Gastronomia WHERE Kod = @MB
		END
	END
END
GO

CREATE FUNCTION FILM_RAPORT (@Kod NVARCHAR(12))
RETURNS @tab TABLE(
	Nazwa NVARCHAR(30),
	Dochód MONEY,
	Bilety BIGINT,
	[Procentowo (%)] INT
)
AS
BEGIN
	DECLARE @N NVARCHAR(30), @D MONEY, @B BIGINT, @P INT
	IF @Kod IS NULL
	BEGIN
		INSERT INTO @tab SELECT F.Nazwa, ZPF.ZP, ZPF.CK, 100/(SELECT SUM([Zapłacono (PLN)]) FROM Bilety)*ZPF.ZP
		FROM Filmy F JOIN ( SELECT [Kod Filmu], SUM([Zapłacono (PLN)]) AS ZP, COUNT(Kod) AS CK
						    FROM Bilety GROUP BY [Kod Filmu]) AS ZPF 
		ON F.Kod = ZPF.[Kod Filmu]
	END
	ELSE
	BEGIN
		INSERT INTO @tab SELECT F.Nazwa, ZPF.ZP, ZPF.CK, 100/(SELECT SUM([Zapłacono (PLN)]) FROM Bilety)*ZPF.ZP
		FROM Filmy F JOIN ( SELECT SUM([Zapłacono (PLN)]) AS ZP, COUNT(Kod) AS CK
						    FROM Bilety WHERE [Kod Filmu] = @Kod) AS ZPF 
		ON F.Kod = @Kod
	END
	RETURN
END
GO

CREATE FUNCTION BEST_PRACOWNIK()
RETURNS @tab TABLE(
	ID SMALLINT,
	Imię NVARCHAR(15),
	Nazwisko NVARCHAR(15),
	[Data Zatrudnienia] DATE,
	[Suma (PLN)] MONEY,
	[Sprzedane] INT
)
AS
BEGIN
	DECLARE @ID SMALLINT, @IM NVARCHAR(15), @NA NVARCHAR(15), @DZ DATE, @S MONEY, @SP INT
	SELECT @ID = K.Pracownik, @S = K.DO, @SP = K.CO FROM 
			  (SELECT TOP 1 Pracownik, SUM([Cena (PLN)]) AS DO, COUNT(*) AS CO
			   FROM Sprzedaż 
			   GROUP BY Pracownik 
			   ORDER BY DO DESC) AS K 

	SELECT @IM = Imię, @NA = Nazwisko, @DZ = [Data Zatrudnienia]
	FROM Pracownicy P JOIN [Rejestr Pracowników] RP ON P.ID = @ID AND P.PESEL = RP.PESEL

	INSERT @tab VALUES (@ID, @IM, @NA, @DZ, @S, @SP)

	RETURN
END
GO

CREATE FUNCTION TOP_PRODUCENTOW()
RETURNS @tab TABLE(
	Numer SMALLINT,
	Nazwa NVARCHAR(30),
	Typ NVARCHAR(20),
	[Ilosc towaru] SMALLINT,
	[Dochód (PLN)] MONEY
)
AS
BEGIN
	DECLARE @Numer SMALLINT, @Nazwa NVARCHAR(30), @Typ NVARCHAR(20), @IT SMALLINT, @DP MONEY
	SELECT @Numer = TS.Producent, @DP = TS. SU, @IT = TS.CO FROM
		(SELECT TOP 1 Producent, SUM(S.[Cena (PLN)]) AS SU, COUNT(*) AS CO 
		FROM Towar T JOIN Sprzedaż S ON T.[Kod Filmu] = S.Kod
		GROUP BY Producent ORDER BY SU DESC) AS TS
	SELECT @Nazwa = Nazwa, @Typ = Typ FROM Producenci WHERE Numer = @Numer
	INSERT @tab VALUES (@Numer, @Nazwa, @Typ, @IT, @DP)

	SELECT @Numer = TS.Producent, @DP = TS. SU, @IT = TS.CO FROM
		(SELECT TOP 1 Producent, SUM(S.[Cena (PLN)]) AS SU, COUNT(*) AS CO 
		FROM Towar T JOIN Sprzedaż S ON T.[Kod Gastro] = S.Kod
		GROUP BY Producent ORDER BY SU DESC) AS TS
	SELECT @Nazwa = Nazwa, @Typ = Typ FROM Producenci WHERE Numer = @Numer
	INSERT @tab VALUES (@Numer, @Nazwa, @Typ, @IT, @DP)

	RETURN
END
GO

CREATE FUNCTION CZŁONKOSTWO_FILMY (@NR SMALLINT)
RETURNS @tab TABLE(
	NR SMALLINT,
	Imię NVARCHAR(15),
	Nazwisko NVARCHAR(15),
	[Kod Filmu] NVARCHAR(12),
	Data DATE
)
AS
BEGIN
	DECLARE @N SMALLINT, @IM NVARCHAR(15), @NA NVARCHAR(15), @KF NVARCHAR(12), @D DATE 

	IF @NR IS NULL
	BEGIN
		INSERT @tab SELECT NR, Imię, Nazwisko, FB.[Kod Filmu], FB.Data 
		FROM Członkostwo C JOIN ( SELECT Klient, [Kod Filmu], Data FROM Bilety ) AS FB
		ON C.NR = FB.Klient 
	END
	ELSE
	BEGIN
		INSERT @tab SELECT NR, Imię, Nazwisko, FB.[Kod Filmu], FB.Data 
		FROM Członkostwo C JOIN ( SELECT Klient, [Kod Filmu], Data FROM Bilety ) AS FB
		ON C.NR = FB.Klient AND C.NR = @NR
	END
	RETURN
END
GO

CREATE PROCEDURE CHECK_KASY (@D DATE)
AS
	DECLARE @Count SMALLINT, @ID SMALLINT, @Time TIME, @Day NVARCHAR(12)
	SET @Count = 1
	SET @Time = CAST(GETDATE() AS TIME(7))
	SET @Day = DATENAME(dw,GETDATE())

	WHILE ( @Count < 4 )
	BEGIN
		SET @ID = ( SELECT Obsługujący FROM Kasy WHERE NR = @Count AND CONVERT(DATE,Data) = @D )
		IF @ID IS NULL
		BEGIN
			SET @ID = dbo.GET_PR()
			UPDATE Kasy SET Obsługujący = @ID WHERE NR = @Count
			UPDATE Pracownicy SET Kasa = @Count WHERE ID = @ID
		END
		ELSE
		BEGIN
			DECLARE @PN TIME, @PI TIME
			SET @PN = (SELECT Poniedziałek FROM [Godziny Pracy] WHERE ID = @ID)
			SET @PI = (SELECT Piątek FROM [Godziny Pracy] WHERE ID = @ID)

			IF @Day = 'Monday' OR @Day = 'Tuesday' OR @Day = 'Wednesday' OR @Day = 'Thursday'
			BEGIN
				IF CAST(GETDATE() AS TIME(7)) NOT BETWEEN @PN AND CAST(DATEADD(hh,6,@PN) AS TIME(7))
				BEGIN
					UPDATE Pracownicy SET Kasa = NULL WHERE Kasa = @Count
					SET @ID = dbo.GET_PR()
					UPDATE Kasy SET Obsługujący = @ID WHERE NR = @Count
					UPDATE Pracownicy SET Kasa = @Count WHERE ID = @ID
				END
			END
			ELSE
				IF CAST(GETDATE() AS TIME(7)) NOT BETWEEN @PI AND CAST(DATEADD(hh,6,@PI) AS TIME(7))
				BEGIN
					UPDATE Pracownicy SET Kasa = NULL WHERE Kasa = @Count
					SET @ID = dbo.GET_PR()
					UPDATE Kasy SET Obsługujący = dbo.GET_PR() WHERE NR = @Count
					UPDATE Pracownicy SET Kasa = @Count WHERE ID = @ID
				END				
		END
		SET @Count = @Count+1
	END
GO

CREATE PROCEDURE CHECK_SEANSY
AS
	DECLARE @Time TIME, @Day NVARCHAR(12), @Count SMALLINT
	SET @Time = CAST(GETDATE() AS TIME(7))
	SET @Day = DATENAME(dw,GETDATE())
	SET @Count = 0
	WHILE ( @Count < 10)
	BEGIN
		IF  @Day = 'Monday'
		UPDATE Sale SET Obsługujący = dbo.GET_PR(), 
						[Wolne Miejsca] = Miejsca - ( SELECT COUNT(*) FROM Bilety WHERE GETDATE() > Data AND Sala = Nr )
		WHERE Nr = (SELECT TOP 1 Sala FROM Seansy JOIN Filmy ON 
						Seansy.Kod = Filmy.Kod AND
						Poniedziałek < @Time AND @Time < convert(TIME,dateadd(mi,
						DATEPART(MINUTE, Czas),dateadd(hh,DATEPART(HOUR, Czas),Poniedziałek))
					))
		ELSE
		IF  @Day = 'Tuesday'
		UPDATE Sale SET Obsługujący = dbo.GET_PR(), 
						[Wolne Miejsca] = Miejsca - ( SELECT COUNT(*) FROM Bilety WHERE GETDATE() > Data AND Sala = Nr )
		WHERE Nr = (SELECT TOP 1 Sala FROM Seansy JOIN Filmy ON 
						Seansy.Kod = Filmy.Kod AND
						Wtorek < @Time AND @Time < convert(TIME,dateadd(mi,
						DATEPART(MINUTE, Czas),dateadd(hh,DATEPART(HOUR, Czas),Wtorek))
					))
		ELSE
		IF  @Day = 'Wednesday'
		UPDATE Sale SET Obsługujący = dbo.GET_PR(), 
						[Wolne Miejsca] = Miejsca - ( SELECT COUNT(*) FROM Bilety WHERE GETDATE() > Data AND Sala = Nr )
		WHERE Nr = (SELECT TOP 1 Sala FROM Seansy JOIN Filmy ON 
						Seansy.Kod = Filmy.Kod AND
						Środa < @Time AND @Time < convert(TIME,dateadd(mi,
						DATEPART(MINUTE, Czas),dateadd(hh,DATEPART(HOUR, Czas),Środa))
					))
		ELSE
		IF  @Day = 'Thursday'
		UPDATE Sale SET Obsługujący = dbo.GET_PR(), 
						[Wolne Miejsca] = Miejsca - ( SELECT COUNT(*) FROM Bilety WHERE GETDATE() > Data AND Sala = Nr )
		WHERE Nr = (SELECT TOP 1 Sala FROM Seansy JOIN Filmy ON 
						Seansy.Kod = Filmy.Kod AND
						Czwartek < @Time AND @Time < convert(TIME,dateadd(mi,
						DATEPART(MINUTE, Czas),dateadd(hh,DATEPART(HOUR, Czas),Czwartek))
					))
		ELSE
		IF  @Day = 'Friday'
		UPDATE Sale SET Obsługujący = dbo.GET_PR(), 
						[Wolne Miejsca] = Miejsca - ( SELECT COUNT(*) FROM Bilety WHERE GETDATE() > Data AND Sala = Nr )
		WHERE Nr = (SELECT TOP 1 Sala FROM Seansy JOIN Filmy ON 
						Seansy.Kod = Filmy.Kod AND
						Piątek < @Time AND @Time < convert(TIME,dateadd(mi,
						DATEPART(MINUTE, Czas),dateadd(hh,DATEPART(HOUR, Czas),Piątek))
					))
		ELSE
		IF  @Day = 'Saturday'
		UPDATE Sale SET Obsługujący = dbo.GET_PR(), 
						[Wolne Miejsca] = Miejsca - ( SELECT COUNT(*) FROM Bilety WHERE GETDATE() > Data AND Sala = Nr )
		WHERE Nr = (SELECT TOP 1 Sala FROM Seansy JOIN Filmy ON 
						Seansy.Kod = Filmy.Kod AND
						Sobota < @Time AND @Time < convert(TIME,dateadd(mi,
						DATEPART(MINUTE, Czas),dateadd(hh,DATEPART(HOUR, Czas),Sobota))
					))
		ELSE
		IF  @Day = 'Sunday'
		UPDATE Sale SET Obsługujący = dbo.GET_PR(), 
						[Wolne Miejsca] = Miejsca - ( SELECT COUNT(*) FROM Bilety WHERE GETDATE() > Data AND Sala = Nr )
		WHERE Nr = (SELECT TOP 1 Sala FROM Seansy JOIN Filmy ON 
						Seansy.Kod = Filmy.Kod AND
						Niedziela < @Time AND @Time < convert(TIME,dateadd(mi,
						DATEPART(MINUTE, Czas),dateadd(hh,DATEPART(HOUR, Czas),Niedziela))
					))
		SET @Count = @Count+1
	END
GO

CREATE PROCEDURE DISPLAY_ALL
AS
	SELECT * FROM [Rejestr Pracowników]
	SELECT * FROM Pracownicy
	SELECT * FROM Członkostwo
	SELECT * FROM Kasy
	SELECT * FROM Sale
	SELECT * FROM Producenci
	SELECT * FROM Filmy
	SELECT * FROM Gastronomia
	SELECT * FROM Towar
	SELECT * FROM Sprzedaż
	SELECT * FROM Seansy
	SELECT * FROM Bilety
GO

CREATE PROCEDURE SPRZEDAC
AS
BEGIN
	DECLARE @Count SMALLINT, @Kod NVARCHAR(12), @Pracownik SMALLINT, @Klient SMALLINT
	SET @Count = 0

	WHILE ( @Count < 6 )
	BEGIN
		IF DATEPART(mi, GETDATE()) % 2 = 0
			SET @Klient = NULL
		ELSE
			SET @Klient = (SELECT NR FROM (SELECT TOP 1 * FROM Członkostwo ORDER BY NEWID()) AS C)

		SET @Pracownik = (SELECT Obsługujący FROM (SELECT TOP 1 * FROM Kasy WHERE Stan = 'Aktywna' ORDER BY NEWID()) AS S)
		
		IF @Count < 3
			SET @Kod = (SELECT Kod FROM ( SELECT TOP 1 * FROM Filmy ORDER BY NEWID()) AS F)
		ELSE
			SET @Kod = (SELECT Kod FROM ( SELECT TOP 1 * FROM Gastronomia ORDER BY NEWID()) AS G)

		EXEC SPRZEDANE @Kod,@Pracownik,@Klient
		SET @Count = @Count + 1
	END
END
GO

CREATE PROCEDURE TOTAL_CHECK
AS
	DECLARE @Count SMALLINT, @Time TIME, @Day DATE
	SET @Time = CAST(GETDATE() AS TIME(7))
	SET @Day = CONVERT (DATE,(SELECT TOP 1 Data FROM Kasy WHERE Stan = 'Aktywna'))

	IF @Time BETWEEN '08:00:00' AND '20:00:00' AND ( @Day IS NULL OR CONVERT(DATE,GETDATE()) = @Day )
	BEGIN
		IF NOT EXISTS ( SELECT * FROM Kasy WHERE Stan = 'Aktywna' )
			EXEC KASY_INIT
		ELSE
			EXEC CHECK_KASY @Day

		EXEC SPRZEDAC
		EXEC CHECK_SEANSY
		DELETE FROM Bilety WHERE Data < GETDATE()
	END
	ELSE
	BEGIN
		SET @Count = 1
		WHILE ( @Count < 11 )
		BEGIN
			IF @Count < 4 
				UPDATE Kasy SET Stan = 'Nieaktywna', Obsługujący = NULL WHERE NR = @Count
			UPDATE Sale SET Obsługujący = NULL WHERE Nr = @Count
			UPDATE Pracownicy SET Kasa = NULL WHERE Kasa IS NOT NULL

			SET @Count = @Count+1
		END
	END
	EXEC DISPLAY_ALL
GO